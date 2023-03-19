function [ok,remedy]=checkMount(U,full,remediate)
% check the functionality of the mount, report problems and
%  suggest remedies. This method is specifically designed to check
%  mount related properties of unitCS, which can be either an
%  instrument or a remote class; it is therefore an obs.unitCS method,
%  not a obs.mount method.
%  It is mostly intended to be used in the
%  session where the master unitCS object is defined.
% Arguments:
% if full=true, try to nudge the mount for a more comprehensive
%   (longer) test [not implemented yet]
% if remediate=true, try to apply some remedies    
    arguments
        U obs.unitCS
        full logical =false; % test full operation, e.g. move focusers
        remediate logical = false; % attempt remediation actions
    end
    
    remedy=false;

    % check mount power
    try
        ok=U.MountPower;
        if ~ok && remediate
            remedy=true;
            U.report('mount power is off, trying to turn on\n')
            U.MountPower=true;
            pause(4)
            U.report('attempting to connect the mount\n')
            U.Mount.connect(U.Mount.PhysicalPort);
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
                remedy=true;
                U.report('attempting to reconnect the mount\n')
                U.Mount.connect(U.Mount.PhysicalPort);
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
                remedy=true;
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
        U.report('trying to change HA and Dec of 1°\n')
        HA=U.Mount.HA;
        Dec=U.Mount.Dec;
        U.Mount.goTo(HA+1,Dec+1,'ha')
        pause(5)
        HAdiff=mod(U.Mount.HA-1-HA+180,360)-180;
        Decdiff=mod(U.Mount.Dec-1-Dec+180,360)-180;
        U.report('  deviations: HA %f", Dec %f"\n',HAdiff*3600,Decdiff*3600)
        ok=abs(HAdiff)<0.01 & abs(Decdiff)<0.01 & strcmp(U.Mount.Status,'idle');
        % what would be the remediation otherwise?
        if ok
            % revert the mount to original position and check again
            U.report('moving back the mount to original position\n')
            U.Mount.goTo(HA,Dec,'ha')
            pause(5)
            HAdiff=mod(U.Mount.HA-HA+180,360)-180;
            Decdiff=mod(U.Mount.Dec-Dec+180,360)-180;
            U.report('  deviations: HA %f", Dec %f"\n',HAdiff*3600,Decdiff*3600)
            ok=abs(HAdiff)<0.01 & abs(Decdiff)<0.01 & strcmp(U.Mount.Status,'idle');
            % what would be the remediation otherwise?
            if ok
                % set the mount in tracking
                U.report('setting the mount in tracking mode\n')
                U.Mount.track
                pause(1)
                ok=strcmp(U.Mount.Status,'tracking');
                if ok
                    U.report('  mount tracks succesfully\n')
                else
                    U.report('  mount tracking mode failed\n')
                end
                % revert to non-tracking
                U.Mount.track(false);
            end
        end
    end