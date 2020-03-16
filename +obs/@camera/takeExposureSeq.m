function Imgs=takeExposureSeq(CameraObj,num,ExpTime)
% blocking function, take N images. This should be done in Live mode;
%  but since there are so many issues with it with the QHY, as a functional
%  placeholder we implement it as a repeated take of single exposures.
%  This implies a large overhead for reading and rearming the take each
%  time.
% The many issues of the QHY sdk for live mode include: cumbersome
% requirement for the order of calls for initializing the camera; different
% requirements for the QHY367 and the QHY600; inconsistent state reporting
% of the polling-for-image-ready function; overrun destroys sequence take;
% bad error recovery.
   Imgs = CameraObj.CameraDriverHndl.takeExposureSeq(num, ExpTime);    
end