function abort(CameraObj)
   % Abort exposure
%    CameraObj.checkIfConnected;
   CameraObj.CamHn.abort;
   CameraObj.LogFile.writeLog('Abort exposure')
end
