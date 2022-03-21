function [ok]=checkWholeUnit(U,full,remediate)
% Perform several sanity tests and checks on the objects of the unit,
%  check the connection status with the hardware,
%  report and optionally attempt to solve problems.
% This method can be called after unitCS.connect, and is most useful when
%  called in the Master unit session
    arguments
        U obs.unitCS
        full logical =false; % test full operation, e.g. move focusers, take images
        remediate logical = false; % attempt remediation actions
    end

    U.report('Checking definitions and connections of unit %s:\n',U.Id)

    % check communication with slaves
    for i=1:numel(U.Slave)
        status=U.Slave{i}.Status;
        U.report('Slave %d status: "%s"\n',i,status)
        ok=strcmp(status,'alive');
        if ~ok && remediate
            % attempt disconnection and reconnection
            U.Slave{i}.disconnect;
            pause(15)
            U.connectSlave(i)
            ok=strcmp(U.Slave{i}.Status,'alive');
        end
    end

    % check definition and reachability of the power switches
    if ok
        ok=U.checkSwitches(remediate);
    end

    % check mount
    if ok
        okm=U.checkMount(full,remediate);
    end
    
    % check cameras
    okc=false(1,numel(U.Camera));
    if ok
        for i=1:numel(U.Camera)
            okc(i)=U.checkCamera(i,full,remediate);
        end
    end

    % check focusers
    okf=false(1,numel(U.Focuser));
    if ok
        for i=1:numel(U.Focuser)
            okf(i)=U.checkFocuser(i,full,remediate);
        end
    end

    ok = ok && okm && all(okc) && all(okf);
    if ok
        U.report('all checks OK\n')
    else
         U.report('check failed!\n')
    end
