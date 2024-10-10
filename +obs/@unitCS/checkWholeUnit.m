function [ok,remedy,usable]=checkWholeUnit(U,full,remediate,itel)
% Perform several sanity tests and checks on the objects of the unit,
%  checks the connection status with the hardware, report and optionally 
%  attempt to solve problems.
% Checking short circuits failure of essential components, i.e., if Slaves
%   are required but not ok we do not proceed at checking individual cameras,
%   if switches are not ok we don't check the mount, etc.
% This method can be called after unitCS.connect, and is most useful when
%  called in the Master unit session
%
% Optional arguments:
% -full [default false], try some operative tests (nudge focusers, take images);
%   takes longer
% -remediate [default false], try to apply some remedies
% -itel [default empty] telescopes to check (it is acceptable to operate an
%   unit with missing telescopes). If empty, all telescopes of the unit.
%
% Returns:
% -ok : true if all checks for the prescribed units succeeded
% -remedy: true if remediation was asked for and was necessary
% -usable: logical array, true for each telescope which is in condition to
%          work (i.e. mount, focuser and camera ok). If at input itel did
%          not request all telescopes, usable will be false for those not
%          checked
    arguments
        U obs.unitCS
        full logical =false; % test full operation, e.g. move focusers, take images
        remediate logical = false; % attempt remediation actions
        itel = []; % which telescopes to check
    end

    if isempty(itel)
        itel=1:numel(U.Camera);
        usable=false(1,numel(U.Camera));
    end
    
    remedy=false;
    okSwitches=false;
    okMount=false;

    U.report('Checking definitions and connections of unit %s:\n',U.Id)
    U.GeneralStatus='Checking sanity of unit';

    % check communication with slaves
    % First, find out which are the slaves that we really need to check
    %  (e.g., if we are only caring for a subset of the telescopes)
    % Note, if the unit has not yet been connected, no remoteUnit object
    %  will be defined, and no Slave will be thought relevant
    relevantslaves=false(1,numel(U.Slave));
    okSlaves=relevantslaves;
%     for i=1:numel(U.Slave)
%         for j=itel
%             if isa(U.Camera{j},'obs.remoteClass') && ...
%                  ~isempty(U.Camera{j}.Messenger) && ...
%                  ~isempty(U.Slave(i).Messenger) && ...
%                   U.Slave(i).Messenger==U.Camera{j}.Messenger
%                 relevantslaves(i)=true;
%             end
%         end
%         for j=itel
%             if isa(U.Focuser{j},'obs.remoteClass') && ...
%                   ~isempty(U.Focuser{j}.Messenger) &&...
%                   ~isempty(U.Slave(i).Messenger) && ...
%                    U.Slave(i).Messenger==U.Focuser{j}.Messenger
%                 relevantslaves(i)=true;
%             end
%         end
%     end
    
    % much simpler: relevant slaves to be checked found searching itel in 
    %  RemoteTelescopes
    for i=1:numel(U.Slave)
        for j=itel
            if any(U.RemoteTelescopes{i}==j)
                relevantslaves(i) = true;
            end
        end
    end
    
    for i=find(relevantslaves)
        status=U.Slave(i).Status;
        U.report('Slave %d status: "%s"\n',i,status)
        okSlaves(i)=strcmp(status,'alive');
        if ~okSlaves(i) && remediate
            remedy=true;
            % attempt disconnection and reconnection
            if ~strcmp(status,'disconnected')
                U.report('attempting termination of slave %d\n',i)
                U.Slave(i).terminate(true);
                pause(5)
            end
            % this IS tricky, because connectSlave uses inputname()
            U.report('creation of the slave %d anew\n',i)
            evalin('caller',sprintf('%s.connectSlave(%d)',inputname(1),i));
            okSlaves(i)=strcmp(U.Slave(i).Status,'alive');
        end
    end

    ok = isempty(relevantslaves) || any(okSlaves);

    % check definition and reachability of the power switches
    %  First, find out if for the required subset of telescopes and mount
    %  we need to check all of them
    remedyS=false;
    if ok
        [okSwitches,remedyS]=U.checkSwitches(remediate,itel);
        ok = ok & okSwitches;
    end
    
    % check mount
    remedyM=false;
    if ok
        [okMount,remedyM]=U.checkMount(full,remediate);
    end
    
    % before checking cameras and focusers, make sure that if they are remote
    %  the corresponding slave is ok. Otherwise, it doesn't make sense to
    %  waste time in trying to remediate by power cycling or reconnecting
    cameraslave=zeros(1,numel(U.Camera));
    focuserslave=zeros(1,numel(U.Camera));
    
    for i=1:numel(U.Slave)
        for j=itel
            if isa(U.Camera{j},'obs.remoteClass') && ...
                 ~isempty(U.Camera{j}.Messenger) && ...
                 ~isempty(U.Slave(i).Messenger) && ...
                  U.Slave(i).Messenger==U.Camera{j}.Messenger
                cameraslave(j)=i;
            end
        end
        for j=itel
            if isa(U.Focuser{j},'obs.remoteClass') && ...
                  ~isempty(U.Focuser{j}.Messenger) &&...
                  ~isempty(U.Slave(i).Messenger) && ...
                   U.Slave(i).Messenger==U.Focuser{j}.Messenger
                focuserslave(j)=i;
            end
        end
    end
    
    % check cameras
    okCameras=false(1,numel(itel));
    remedyC=okCameras;
    if ok
        for i=1:numel(itel)
            cs=cameraslave(itel(i));
            if cs>0 && okSlaves(cs)
                [okCameras(i),remedyC(i)]=U.checkCamera(itel(i),full,remediate);
            end
        end
    end

    % check focusers
    okFocusers=false(1,numel(itel));
    remedyF=okFocusers;
    if ok
        for i=1:numel(itel)
            fs=focuserslave(itel(i));
            if fs>0 && okSlaves(fs)
                [okFocusers(i),remedyF(i)]=U.checkFocuser(itel(i),full,remediate);
            end
        end
    end

    ok = ok && okMount && all(okCameras) && all(okFocusers);
    remedy = remedy || remedyS || remedyM || any(remedyC) || any(remedyF);
    usable(itel) = repmat(okSwitches,1,numel(itel)) & repmat(okMount,1,numel(itel)) & okCameras & okFocusers;
    if ok
        U.GeneralStatus='ready';
        if ~remedy
            U.report('all checks OK\n')
        else
            U.report('all checks ok, but after remediation\n')
        end
    else
        U.GeneralStatus='not ready';
        if ~remedy
            U.report('check failed!\n')
        else
            U.report('check failed, even after remediation!\n')
        end
    end
