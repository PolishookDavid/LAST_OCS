function success=disconnect(CameraObj)
    % Close the connection with the camera registered in the current camera object
   success=CameraObj.CamHn.disconnect;
   CameraObj.LogFile.writeLog(sprintf('call disconnect from camera'))
end
