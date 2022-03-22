function ok=checkMount(U,full,remediate)
% check the functionality of the mount, report problems and
%  suggest remedies. This method is specifically designed to check
%  mount related properties of unitCS, which can be either an
%  instrument or a remote class; it is therefore an obs.unitCS method,
%  not a obs.mount method.
%  It is mostly intended to be used in the
%  session where the master unitCS object is defined.
% Arguments:
% if full=true, try to nudge the focuser for a more comprehensive
%   (longer) test
% if remediate=true, try to apply some remedies
    arguments
        U obs.unitCS
        full logical =false; % test full operation, e.g. move focusers
        remediate logical = false; % attempt remediation actions
    end
    
    % check mount power
    try
        ok=U.MountPower;
        if ~ok && remediate
                U.report('mount power is off, trying to turn on\n')
                U.MountPower=true;
        end
        ok=true;
        U.report('mount is powered\n')
    catch
        % abort
        ok=false;
        U.report('cannot turn on the mount\n')
    end

    % check communication with mount
    if ok
        U.Mount.HA;
        ok=isempty(U.Mount.LastError);
        % remediation: reconnect
        if ~ok
            U.report('cannot read HA from the mount\n')
            if remediate
                U.report('attempting to reconnect the mount\n')
                U.Mount.connect;
                ok=isempty(U.Mount.LastError);
            end
        end
    end
    
    if ok
        % check for mount faults
        try
            F=U.Mount.LatchedFaults;
            nha=fieldnames(F.HA);
            ndec=fieldnames(F.Dec);
            for i=1:length(nha)
                if F.HA.(nha{i})
                    ok=false;
                    U.report('HA fault: %s\n',nha{i})
                end
            end
            for i=1:length(ndec)
                if F.HA.(ndec{i})
                    ok=false;
                    U.report('Dec fault: %s\n',ndec{i})
                end
            end
            % remediation: clearFaults
            if ~ok && remediate
                U.report('attempting to clear mount faults\n')
                U.Mount.clearFaults
                ok=true; % hopefully, might better to recheck
            end
        catch
            ok=false;
            U.report('error while reading mount fault state\n')
        end
    end

    if ok && full
        % nudge the mount, perhaps? really?
    end