function [ok,remedy]=checkWholeUnit(U,full,remediate)
% Perform several sanity tests and checks on the objects of the unit,
%  check the connection status with the hardware,
%  report and optionally attempt to solve problems.
% This method can be called after unitCS.connect, and is most useful when
%  called in the Master unit session
% Optional arguments:
% -full [default false], try some operative tests (nudge focusers, take images);
%   takes longer
% -remediate [default false], try to apply some remedies
    arguments
        U obs.unitCS
        full logical =false; % test full operation, e.g. move focusers, take images
        remediate logical = false; % attempt remediation actions
    end

    ok=true;
    remedy=false;

    U.report('Checking definitions and connections of unit %s:\n',U.Id)

    % check communication with slaves
    for i=1:numel(U.Slave)
        status=U.Slave{i}.Status;
        U.report('Slave %d status: "%s"\n',i,status)
        ok=strcmp(status,'alive');
        if ~ok && remediate
            remedy=true;
            % attempt disconnection and reconnection
            if ~strcmp(status,'disconnected')
                U.report('attempting termination of slave %d\n',i)
                U.Slave{i}.terminate(true);
                pause(5)
            end
            % this IS tricky, because connectSlave uses inputname()
            U.report('creation of the slave %d anew\n',i)
            evalin('caller',sprintf('%s.connectSlave(%d)',inputname(1),i));
            ok=strcmp(U.Slave{i}.Status,'alive');
        end
    end

    % check definition and reachability of the power switches
    remedyS=false;
    if ok
        [ok,remedyS]=U.checkSwitches(remediate);
    end

    % check mount
    remedyM=false;
    if ok
        [okm,remedyM]=U.checkMount(full,remediate);
    end
    
    % check cameras
    okc=false(1,numel(U.Camera));
    remedyC=okc;
    if ok
        for i=1:numel(U.Camera)
            [okc(i),remedyC(i)]=U.checkCamera(i,full,remediate);
        end
    end

    % check focusers
    okf=false(1,numel(U.Focuser));
    remedyF=okf;
    if ok
        for i=1:numel(U.Focuser)
            [okf(i),remedyF(i)]=U.checkFocuser(i,full,remediate);
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
