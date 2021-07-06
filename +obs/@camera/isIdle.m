function Flag = isIdle(CameraObj)
    % Return true (per camera) if camera is idle
    switch lower(CameraObj.CamStatus)
        case 'idle'
            Flag = true;
        otherwise
            Flag = false;
    end
end
