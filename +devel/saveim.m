function saveim(CamObj,MountObj,FocObj,ImType)
% devel.saveim(C,M,F,'science')

RAD = 180./pi;
EastLong = 34.9./RAD;


if nargin<3
    Focus = NaN;
end

PWD = pwd;
cd /home/last/images

Date    = datestr(CamObj.TimeStart,'yyyymmdd.HHMMSS.FFF');
DateObs = datestr(CamObj.TimeStart,'yyyy-mm-ddTHHMMSS.FFF');
DateVec = datevec(CamObj.TimeStart);
JD      = celestial.time.julday(DateVec(:,[3 2 1 4 5 6]));
LST     = celestial.time.lst(JD,EastLong,'a');

DirName = datestr(now,'yyyymmdd'); % need to correct this to begining of night
if exist(DirName,'dir')==0
    % create dir
    mkdir(DirName);
end
cd(DirName);


FileName = sprintf('LAST_n0_t1_%s_ZWO_mono_%s.fits',Date,ImType);
%S = SIM;
Image = CamObj.LastImage;
Header = {'NAXIS',2,'number of axes';...
          'NAXIS1',size(Image,2),'size of axis 1 (X)';...
          'NAXIS2',size(Image,1),'size of axis 2 (Y)';...
          'BITPIX',-32,'bits per data value';...
          'BZERO',0.0,'zero point in scaling equation';...
          'BSCALE',1.0,'linear factor in scaling equation';...
          'BUNIT','ADU','physical units of the array values';...
          'IMTYPE',ImType,'Image type: dark/flat/focus/science/test';...
          'INTGAIN',CamObj.Gain,'Camera internal gain level';...
          'INTOFFS',CamObj.Offset,'Camera internal offset level';...
          'BINX',CamObj.Binning(1),'Camera binning in X-axis';...
          'BINY',CamObj.Binning(2),'Camera binning in Y-axis';...
          'FOCUS',FocObj.Pos,'Focus value';...
          'PRFOCUS',FocObj.LastPos,'Previous Focus value';...
          'ORIGIN','Weizmann Institute of Science','organization responsible for the data';...
          'TELESCOP','LAST','name of telescope';...
          'CAMERA',CamObj.CameraName,'Camera name';...
          'INSTRUME','LAST-0-1-1-1','LAST-node-mount-telescope-camera';...
          'OBSERVER','LAST','observer who acquired the data';...
          'REFERENC','NAN','bibliographic reference';...
          'EXPTIME',CamObj.ExpTime,'Exposure time (s)';...
          'TEMP_DET',CamObj.Temperature,'Detector temperature';...
          'RA',MountObj.RA,'J2000.0 R.A. [deg]';...
          'DEC',MountObj.Dec,'J2000.0 Dec. [deg]';...
          'HA',LST.*360 - MountObj.RA,'Hour Angle [deg]';...
          'LST',LST.*360,'LST [deg]';...
          'AZ',MountObj.Az,'Azimuth';...
          'ALT',MountObj.Alt,'Altitude';...
          'TRACKSP',MountObj.TrackingSpeed,'';...
          'CWDOWN',MountObj.IsCounterWeightDown,'Is Counter Weight Down flag';...
          'CDELT1',0.000347,'coordinate increment along axis 1 (deg/pix)';...
          'CDELT2',0.000347,'coordinate increment along axis 2 (deg/pix)';...
          'SCALE',1.251,'Pixel scale (arcsec/pix)';...
          'DATE-OBS',DateObs,'date of the observation';...
          'JD',JD,'Julian day';...
          'MJD',JD-2400000.5,'Modified Julian day';...
          'EQUINOX','J2000.0','Equinox of coordinates'};
         % 'END','',''};
    
FITS.write(single(Image),FileName,'Header',Header,'DataType','single');

%cd(PWD);

