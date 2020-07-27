function coolingOff(CameraObj)
   % Turn camera cooling off
   if CameraObj.checkIfConnected
      CameraObj.LogFile.writeLog('Call Cooling off')
      CameraObj.CamHn.coolingOff;
      CameraObj.LastError = CameraObj.CamHn.lastError;
   end
end