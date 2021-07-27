function FocRes=focus_camera(CameraObj, varargin)
    % Execute focus loop on current camera

    if isempty(CameraObj.HandleMount)
        CameraObj.LogFile.write('HandleMount must be specified while calling focus_camera');
        error('HandleMount must be specified while calling focus_camera');
    end
    if isempty(CameraObj.HandleFocuser)
        CameraObj.LogFile.write('HandleFocuser must be specified while calling focus_camera');
        error('HandleFocuser must be specified while calling focus_camera');
    end
    [FocRes] = obs.util.tools.focus_loop(CameraObj,CameraObj.HandleMount,CameraObj.HandleFocuser,[],varargin{:}); 
end
