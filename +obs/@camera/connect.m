function CameraObj=connect(CameraObj)
    % Superclass method called after the driver method: loads and effects
    %  the connect configuration, after the driver has correctly opened the
    %  communication with the camera
    CameraObj.report('Loading post connection configuration for camera %s\n',...
                     CameraObj.Id)
    % load configuration
    CameraObj.loadConfig(CameraObj.configFileName('connect'))

end
