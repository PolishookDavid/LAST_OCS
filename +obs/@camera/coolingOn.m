function coolingOn(CameraObj,Temp)
   % Turn camera cooling on and set temperature, if given
   if CameraObj.checkIfConnected

      CameraObj.LogFile.writeLog(sprintf('Call Cooling on, temperarture=%.1f', Temp))

      if nargin < 2
         Temp = CameraObj.Temperature;
      end

      % Call coolingOn using the camera handle object
      CameraObj.Handle.coolingOn(Temp);
      CameraObj.LastError = CameraObj.Handle.lastError;
   end
end