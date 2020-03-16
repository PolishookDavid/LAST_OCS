function startExposure(CameraObj,expTime)
% set up the scenes for taking a single exposure
   CameraObj.CameraDriverHndl.startExposure(expTime);
end
