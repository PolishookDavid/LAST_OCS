function takeExposure(CameraObj,expTime)
% like startExposure+collectExposure, but the latter is called by a timer, 
%  which collects the image behind the scenes when expTime is past.
% The resulting image goes in QC.lastImage
   CameraObj.CameraDriverHndl.takeExposure(expTime);

   % Start timer
   CameraObj.ReadoutTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'camera-timer', ...
                          'Period', 1, 'StartDelay', 1, 'TimerFcn', CameraObj.callback_timer, 'ErrorFcn', 'beep');
                     
   start(CameraObjTimer);


      
%    Image = SIM;
% Image.Im = int16(Data);
% 
% % adding keywords to header
% Date = convert.time(HD,'JD','StrDate')
% H = H.add_key('SIMPLE',true,'does file conform to the Standard?');
% H = H.add_key('BSCALE',true,'linear factor in scaling equation');
% H = H.add_key('BZERO',true,'zero point in scaling equation');
% H = H.add_key('BUNIT',true,'physical units of the array values');
% H = H.add_key('BITPIX',16,'');
% H = H.add_key('NAXIS',2,'');
% H = H.add_key('NAXIS1',size(Data,2),'');
% H = H.add_key('NAXIS2',size(Data,1),'');
% H = H.add_key('TYPE',ImageType,'');
% H = H.add_key('EXPTIME',1,'');
% H = H.add_key('JD',JD,'');
% H = H.add_key('UTC-OBS',Date{1},'');
% H = H.add_key('FILTER',Filter,'');
% H = H.add_key('CAMERA',Camera,'');
% H = H.add_key('TELESCOPE',Telescope,'');
% H = H.add_key('END','','')
% 
% Image.Head = H;
% 
% 
% % write fits header
% FITS.write(Image.Im,FileName,'Header',Image.Head,'DataType',16);

end