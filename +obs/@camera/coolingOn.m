function coolingOn(CameraObj,temp)
% Turn cooling on and set target temperature, if given
% the default target tempetarure, if not given, is -20°C (arbitrarily)
   CameraObj.CameraDriverHndl.coolingOn(temp);
end