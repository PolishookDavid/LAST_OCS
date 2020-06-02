function takeDarkImages(CameraObj, ImagesNum, ExpTime)

   if exist('ExpTime','var')
      CameraObj.ExpTime = ExpTime;
   end
   
   CameraObj.ImType = 'Dark';
   CameraObj.SaveOnDisk = 1;
   CameraObj.ToDisplay = 0;

   for I=1:1:ImagesNum,
      CameraObj.takeExposure;
   end
end