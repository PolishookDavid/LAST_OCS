function Imgs=takeExposureSeq(CameraObj,num,ExpTime)
% SHOULD BE CHANGED
   CameraObj.checkIfConnected
   Imgs = CameraObj.CamHn.takeExposureSeq(num, ExpTime);    
end