function Imgs=takeExposureSeq(CameraObj,num,ExpTime)
% SHOULD BE CHANGED
   if CameraObj.checkIfConnected
      if nargin < 3
         ExpTime = 10; % sec
      end
      if nargin < 2
         num = 1; % sec
      end

      Imgs = CameraObj.CamHn.takeExposureSeq(num, ExpTime);
      CameraObj.LastError = CameraObj.CamHn.lastError;
   end
end
