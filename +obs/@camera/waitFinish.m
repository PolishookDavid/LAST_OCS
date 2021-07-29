function waitFinish(CameraObj)
    % Wait for the camera to return to idle mode, but not longer than one
    %  exposure time. After that, if the camera is still exposing, send an
    %  abort command. That should interupt also acquisition in Live mode.
    % Decisions are based on  .ExpTime and .CamStatus
    
    % Note: the camera drivers have each an attempt of a WaitForIdle method.
    %  It might be better to handle each camera's quirk in there, i.e. specific
    %  driver functions, rather than relying on a consistent report of
    %  CamStatus by all drivers

    ExpTime=CameraObj.ExpTime;
    PollingTime = min(ExpTime,0.01);

    if isempty(ExpTime)
        CameraObj.reportError('could not even get the exposure time - is the connection with the camera ok?')
        return
    end
    
    t0=now;
    while (now-t0)*3600*24 < ExpTime
        CamStatus=lower(CameraObj.CamStatus);
        switch CamStatus
            case {'exposing','reading'}
                % do nothing - continue waiting
            case 'idle'
                break
            otherwise
                CameraObj.reportError(sprintf('camera %s is in a suspicious "%s" status, exiting',...
                                          CameraObj.Id, CamStatus))
            break
        end
        pause(PollingTime);
    end

    if (now-t0)*3600*24 > ExpTime
        if strcmp(CamStatus,'exposing')
            % make one further attempt to stop (maybe we were in live mode?)
            CameraObj.report('camera keeps being "exposing" for longer than ExpTime - attempting to abort')
            CameraObj.abort
        end
    end
    
end
