function success=disconnect(CameraObj)
   % Close the connection with the camera registered in the current camera object
%    CameraObj.checkIfConnected;
   success=CameraObj.CamHn.disconnect;
   CameraObj.IsConnected = success;
   CameraObj.LogFile.writeLog(sprintf('call disconnect from camera'))
end
