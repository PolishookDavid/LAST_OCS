function coolingOff(CameraObj)
   % Turn camera cooling off
   if CameraObj.checkIfConnected
      CameraObj.LogFile.writeLog('Call Cooling off')
      % Call coolingOff using the camera handle object
      CameraObj.Handle.coolingOff;
      CameraObj.LastError = CameraObj.Handle.LastError;
   end
end
