function Flag=coolingOn(CameraObj)
    % Set cooling on - use Temperature to set temperature
    Flag = false;
    if CameraObj.IsConnected
        Camera.Handle.coolingOn;
        Flag = true;
        CameraObj.LogFile.writeLog('Camera cooling set to on');
    else
        if CameraObj.Verbose
            fprintf('Camera coolingOn function failed because camera is not connected\n');
        end
        CameraObj.LogFile.writeLog('Camera coolingOn function failed because camera is not connected');
    end
end
