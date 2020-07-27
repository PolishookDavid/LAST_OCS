function abort(CameraObj)
   % Abort exposure
   if CameraObj.checkIfConnected
      CameraObj.LogFile.writeLog('Abort exposure')
      CameraObj.CamHn.abort;
      CameraObj.LastError = CameraObj.CamHn.lastError;
   end
end
