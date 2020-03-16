function success=connect(CameraObj,cameranum)
    % Open the connection with a specific camera, and
    %  read from it some basic information like color capability,
    %  physical dimensions, etc.
    %  cameranum: int, number of the camera to open (as enumerated by the SDK)
    %     May be omitted. In that case the last camera is referred to
    
   success = CameraObj.CameraDriverHndl.connect(cameranum);
   switch CameraObj.CameraDriverHndl.lastError
       case "could not even get one camera id"
           CameraObj.lastError = "could not even get one camera id";
   end
end
