function Header=updateHeader(CameraObj)
   RAD = 180./pi;
   DateObs = datestr(CameraObj.TimeStart,'yyyy-mm-ddTHHMMSS.FFF');
   DateVec = datevec(CameraObj.TimeStart);
   JD      = celestial.time.julday(DateVec(:,[3 2 1 4 5 6]));

   if (isempty(CameraObj.HandleMount))
      MountGeoName = 0;
      RA  = NaN;
      Dec = NaN;
      HA  = NaN;
      LST = NaN;
      Az  = NaN;
      Alt = NaN;
      TrackingSpeed = NaN;
      IsCounterWeightDown = NaN;
   else
      MountGeoName = CameraObj.HandleMount.MountNumber;
      RA  = CameraObj.HandleMount.RA;
      Dec = CameraObj.HandleMount.Dec;
      HA  = CameraObj.HandleMount.HA;
      LST = celestial.time.lst(JD,CameraObj.HandleMount.ObsLon./RAD,'a').*360;
      Az  = CameraObj.HandleMount.Az;
      Alt = CameraObj.HandleMount.Alt;
      TrackingSpeed = CameraObj.HandleMount.TrackingSpeed;
      IsCounterWeightDown = NaN; %CameraObj.HandleMount.IsCounterWeightDown;
   end
   
   if (isempty(CameraObj.HandleFocuser))
      FocPos = NaN;
      FocPrevPos = NaN;
   else
      FocPos = CameraObj.HandleFocuser.Pos;
      FocPrevPos = CameraObj.HandleFocuser.LastPos;
   end
   
   ConfigNode=obs.util.config.read_config_file('/home/last/config/config.node.txt');
   ObservatoryNode = ConfigNode.ObservatoryNode;

   % Old config file reading (before Dec 2020):
%   Instrument = sprintf('LAST.%s.%s.%s', obs.util.config.readSystemConfigFile('ObservatoryNode'), MountGeoName, CameraObj.CamGeoName); % 'LAST.node.mount.camera'
   % New config file reading (after Dec 2020):
   Instrument = sprintf('LAST.%s.%s.%s', ObservatoryNode, MountGeoName, CameraObj.CameraGeoName); % 'LAST.node.mount.camera'
   Header = {'NAXIS',2,'number of axes';...
              'NAXIS1',size(CameraObj.LastImage,2),'size of axis 1 (X)';...
              'NAXIS2',size(CameraObj.LastImage,1),'size of axis 2 (Y)';...
              'BITPIX',-32,'bits per data value';...
              'BZERO',0.0,'zero point in scaling equation';...
              'BSCALE',1.0,'linear factor in scaling equation';...
              'BUNIT','ADU','physical units of the array values';...
              'IMTYPE',CameraObj.ImType,'Image type: dark/flat/focus/science/test';...
              'INTGAIN',CameraObj.Gain,'Camera internal gain level';...
              'INTOFFS',CameraObj.Handle.Offset,'Camera internal offset level';...
              'BINX',CameraObj.Binning(1),'Camera binning in X-axis';...
              'BINY',CameraObj.Binning(2),'Camera binning in Y-axis';...
              'ORIGIN','Weizmann Institute of Science','organization responsible for the data';...
              'TELESCOP','Celestron RASA 11','name of telescope';...
              'CAMERA',[CameraObj.CameraType, ' ', CameraObj.CameraModel],'Camera name';...
              'INSTRUME',Instrument,'LAST.node.mount.camera';...
              'OBSERVER','LAST','observer who acquired the data';...
              'REFERENC','NAN','bibliographic reference';...
              'EXPTIME',CameraObj.ExpTime,'Exposure time (s)';...
              'TEMP_DET',CameraObj.Temperature,'Detector temperature';...
              'COOLERPWR',CameraObj.CoolingPower,'Percentage of the cooling power';...
              'RA',RA,'J2000.0 R.A. [deg]';...
              'DEC',Dec,'J2000.0 Dec. [deg]';...
              'HA',HA,'Hour Angle [deg]';...
              'LST',LST,'LST [deg]';...
              'AZ',Az,'Azimuth';...
              'ALT',Alt,'Altitude';...
              'EQUINOX',2000.0,'Coordinates equinox (Julian years)';...
              'TRACKSP',TrackingSpeed,'';...
              'CWDOWN',IsCounterWeightDown,'Is Counter Weight Down flag';...
              'FOCUS',FocPos,'Focus value';...
              'PRFOCUS',FocPrevPos,'Previous Focus value';...
              'CDELT1',0.000347,'coordinate increment along axis 1 (deg/pix)';...
              'CDELT2',0.000347,'coordinate increment along axis 2 (deg/pix)';...
              'SCALE',1.251,'Pixel scale (arcsec/pix)';...
              'DATE-OBS',DateObs,'date of the observation';...
              'JD',JD,'Julian day';...
              'MJD',JD-2400000.5,'Modified Julian day';...
              'OBJECT',CameraObj.Object,'Object/field name'};
end
