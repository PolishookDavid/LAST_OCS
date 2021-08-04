function Flag=waitFinish(MountObj)
    % wait (blocking) until the mount ended slewing and returned to idle mode
    % Result: true if the mount is finally either tracking or standing still
    %  (idle, disconnected, etc.)
    
    % it would be nice if timeout could be determined depending on the
    %  preceding command passed to the mount, as an ETA.
    % Could be made i.e. dependent on the SlewingSpeed, like
    %    360/max(MountObj.SlewingSpeed)
    timeout=30; % sec
    
    Flag=false;
    t0=now;
    while (now-t0)*3600*24 < timeout
        pause(1);
        try
            Status = MountObj.Status;
        catch
            pause(1);
            Status = MountObj.Status;
        end

        switch lower(Status)
            case {'idle','tracking','home','park','aborted','disabled'}
                MountObj.report('\nSlewing is complete\n');
                Flag=true;
                break
            case 'slewing'
                MountObj.report('.');
            otherwise
                MountObj.reportError(sprintf('Mount status: %s',Status));
                break
        end
    end
    
    if (now-t0)*3600*24 >= timeout
        MountObj.report('\n');
        MountObj.reportError('timeout while waiting for mount to finish slewing')
        % to decide whether to try to abort movement, at this point
        %MountObj.abort
    end

end
