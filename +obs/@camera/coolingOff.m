function Flag=coolingOff(CameraObj)
    % Set cooling off
    Flag = false;
    if CameraObj.IsConnected
        Camera.Handle.coolingOff;
        Flag = true;
        CameraObj.LogFile.writeLog('Camera cooling set to off');
    else
        if CameraObj.Verbose
            fprintf('Camera coolingOff function failed because camera is not connected\n');
        end
        CameraObj.LogFile.writeLog('Camera coolingOff function failed because camera is not connected');
    end
end
