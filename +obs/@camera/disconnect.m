function success=disconnect(CameraObj)
    % Close the connection with the camera registered in the current camera object
   success=CameraObj.CameraDriverHndl.disconnect;
   switch CameraObj.CameraDriverHndl.lastError
       case "could not disconnect camera"
           CameraObj.lastError = "could not disconnect camera";
   end
end
