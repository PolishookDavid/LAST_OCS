function success=disconnect(CameraObj)
   % Close the connection with the camera registered in the current camera object
   if CameraObj.checkIfConnected
      CameraObj.LogFile.writeLog(sprintf('call camera.disconnect'))
      % Call disconnect using the camera handle object
      success=CameraObj.Handle.disconnect;
      CameraObj.IsConnected = ~success;
      CameraObj.LastError = CameraObj.Handle.lastError;
   end
end
