function [ok,remedy]=checkWholeUnit(U,full,remediate,itel)
% Perform several sanity tests and checks on the objects of the unit,
%  check the connection status with the hardware,
%  report and optionally attempt to solve problems.
% This method can be called after unitCS.connect, and is most useful when
%  called in the Master unit session
% Optional arguments:
% -full [default false], try some operative tests (nudge focusers, take images);
%   takes longer
% -remediate [default false], try to apply some remedies
% -itel [default empty] telescopes to check (it is acceptable to operate an
%   unit with missing telescopes). If empty, all telescopes of the unit.
    arguments
        U obs.unitCS
        full logical =false; % test full operation, e.g. move focusers, take images
        remediate logical = false; % attempt remediation actions
        itel = []; % which telescopes to check
    end

    if isempty(itel)
        itel=1:numel(U.Camera);
    end
    
    ok=true;
    remedy=false;

    U.report('Checking definitions and connections of unit %s:\n',U.Id)
    U.GeneralStatus='Checking sanity of unit';

    % check communication with slaves
    % First, find out which are the slaves that we really need to check
    %  (e.g., if we are only caring for a subset of the telescopes)
    % Note, if the unit has not yet been connected, no remoteUnit object
    %  will be defined, and no Slave will be thought relevant
    relevantslaves=false(1,numel(U.Slave));
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
        ok=strcmp(status,'alive');
        if ~ok && remediate
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
            ok=strcmp(U.Slave(i).Status,'alive');
        end
    end

    % check definition and reachability of the power switches
    %  First, find out if for the required subset of telescopes and mount
    %  we need to check all of them
    remedyS=false;
    if ok
        [ok,remedyS]=U.checkSwitches(remediate,itel);
    end

    % check mount
    remedyM=false;
    if ok
        [okm,remedyM]=U.checkMount(full,remediate);
    end
    
    % check cameras
    okc=false(1,numel(itel));
    remedyC=okc;
    if ok
        for i=1:numel(itel)
            [okc(i),remedyC(i)]=U.checkCamera(itel(i),full,remediate);
        end
    end

    % check focusers
    okf=false(1,numel(itel));
    remedyF=okf;
    if ok
        for i=1:numel(itel)
            [okf(i),remedyF(i)]=U.checkFocuser(itel(i),full,remediate);
        end
    end

    ok = ok && okm && all(okc) && all(okf);
    remedy = remedy || remedyS || remedyM || any(remedyC) || any(remedyF);
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
