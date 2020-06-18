function abort(CameraObj)
   % Abort exposure
   CameraObj.CamHn.abort;
   CameraObj.LogFile.writeLog('Abort exposure')
end
