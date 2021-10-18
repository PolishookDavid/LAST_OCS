function Flag=waitFinish(CameraObj)
    % Wait for the camera to return to idle mode, but not longer than one
    %  exposure time. After that, if the camera is still exposing, send an
    %  abort command. That should interrupt also acquisition in Live mode.
    % Decisions are based on  .ExpTime and .CamStatus
    % Result: true if the camera is finally idle
    
    % Note: the camera drivers have each an attempt of a WaitForIdle method.
    %  It might be better to handle each camera's quirk in there, i.e. specific
    %  driver functions, rather than relying on a consistent report of
    %  CamStatus by all drivers

    ExpTime=CameraObj.ExpTime;
    PollingTime = min(ExpTime,0.01);
    % do we need an extra overhead time for 'reading'? Usually reading
    %  is either a blocking call of the sdk, or performed within a
    %  callback, and hence .CamStatus is available only after it (??)
    ReadTime=5; % fixed; for the QHY as known it is impossible to anticipate it,
                % devising it from camera parameter and class of USB
                % connection

    if isempty(ExpTime)
        CameraObj.reportError('could not even get the exposure time - is the connection with the camera ok?')
        return
    end
    
    Flag=false;
    t0=now;
    while (now-t0)*3600*24 < ExpTime + ReadTime
        CamStatus=lower(CameraObj.CamStatus);
        switch CamStatus
            case {'exposing','reading'}
                % do nothing - continue waiting
            case 'idle'
                Flag=true;
                break
            otherwise
                CameraObj.reportError('camera %s is in a suspicious "%s" status, exiting',...
                                          CameraObj.Id, CamStatus)
            break
        end
        pause(PollingTime);
    end

    if (now-t0)*3600*24 > ExpTime + ReadTime
        if strcmp(CameraObj.CamStatus,'exposing')
            % make one further attempt to stop (maybe we were in live mode?)
            CameraObj.report('camera keeps being "exposing" for longer than ExpTime - attempting to abort')
            CameraObj.abort
        end
    end
    
end
