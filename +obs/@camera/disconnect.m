function success=disconnect(CameraObj)
   % Close the connection with the camera registered in the current camera object
   if CameraObj.checkIfConnected
      CameraObj.LogFile.writeLog(sprintf('call camera.disconnect'))
      success=CameraObj.CamHn.disconnect;
      CameraObj.IsConnected = ~success;
      CameraObj.LastError = CameraObj.CamHn.lastError;
   end
end
