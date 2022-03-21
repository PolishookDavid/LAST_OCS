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
        if ~U.MountPower
            if remediate
                U.MountPower=true;
            end
        end
        ok=true;
    catch
        % abort
        ok=false;
    end

    % check communication with mount
    % remediation: power cycle
    
    % check for mount faults
    % remediation: clearFaults
 