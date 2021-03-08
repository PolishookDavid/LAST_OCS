function abort(CameraObj)
   % Abort exposure
   if CameraObj.checkIfConnected
      CameraObj.LogFile.writeLog('Abort exposure')
      % Call abort using the camera handle object
      CameraObj.Handle.abort;
      CameraObj.LastError = CameraObj.Handle.LastError;
   end
end
