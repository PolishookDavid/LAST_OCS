function coolingOff(CameraObj)
   % Turn camera cooling off
%    CameraObj.checkIfConnected;
   CameraObj.CamHn.coolingOff;
   CameraObj.LogFile.writeLog('Call Cooling off')
end