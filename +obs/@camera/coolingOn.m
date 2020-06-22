function coolingOn(CameraObj,Temp)
   % Turn camera cooling on and set temperature, if given
   if nargin < 2
      Temp = CameraObj.Temperature;
   end

   CameraObj.checkIfConnected
   CameraObj.CamHn.coolingOn(Temp);
   CameraObj.LogFile.writeLog(sprintf('Call Cooling on, temperarture=%.1f', Temp))
end