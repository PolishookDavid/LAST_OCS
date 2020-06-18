function takeDarkImages(CameraObj, ImagesNum, ExpTime,varargin)
   % Take a set of Dark images
   % ExpTime in seconds
   
   DefV.ReadingOutTime = 5;
   DefV.TimeoutLimit= 10;
   DefV.disp_save = true;
   InPar = InArg.populate_keyval(DefV,varargin,mfilename);

   if exist('ExpTime','var')
      CameraObj.ExpTime = ExpTime;
   else
      ExpTime = CameraObj.ExpTime;
   end
   if ~exist('ImagesNum','var')
      ImagesNum = 1;
   end


   CameraObj.ImType = 'Dark';
   CameraObj.SaveOnDisk = 1;
   CameraObj.Display = 0;

   CameraObj.LogFile.writeLog(sprintf('call takeDarkImages. ImagesNum=%d, ExpTime=%f', ImagesNum, CameraObj.ExpTime))

   for I=1:1:ImagesNum
      CameraObj.takeExposure;
      pause(ExpTime+InPar.ReadingOutTime)
      i = 0;
      while (~strcmpi(CameraObj.CamStatus, 'idle') && i<InPar.TimeoutLimit)
         i = i+1;
         pause(1);
      end
      if (i==InPar.TimeoutLimit)
         if CameraObj.Verbose, fprintf('Dark script: Timeout reached. Camera status is: %s\n', CameraObj.CamStatus); end
         CameraObj.LogFile.writeLog(sprintf('Dark script: Timeout reached. Camera status is: %s\n', CameraObj.CamStatus));
      end
   end
   
   if CameraObj.Verbose, fprintf('Dark method ended.\n'); end
   CameraObj.LogFile.writeLog('Dark method ended')
end