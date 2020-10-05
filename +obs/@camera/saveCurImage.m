function saveCurImage(CameraObj)
% Save last image to disk according the user's settings

   % Construct directory name to save image in
   DirName = obs.util.config.constructDirName('raw');
   cd(DirName);
   CameraObj.LogFile.writeLog(sprintf('cd %s',DirName))


   % Construct image name   
   ImageDate = datestr(CameraObj.TimeStart,'yyyymmdd.HHMMSS.FFF');
   ObservatoryNode = obs.util.config.readSystemConfigFile('ObservatoryNode');
   MountGeoName = obs.util.config.readSystemConfigFile('MountGeoName');

   % Image name legend:    LAST.Node.mount.camera_YYYYMMDD.HHMMSS.FFF_Filter_CCDnum_ImType.fits
   % Image name example:   LAST.1.1.e_20200603.063549.030_clear_0_science.fits
   CameraObj.LastImageName = obs.util.config.constructImageName(ObservatoryNode, MountGeoName, CameraObj.CamGeoName, ImageDate, CameraObj.Filter, CameraObj.CCDnum, CameraObj.ImType, CameraObj.ImageFormat);

%    % Name with serial number - OBSELETE?
%    SerialNum = CameraObj.LastImageSearialNum + 1;
%    CameraObj.LastImageName = sprintf('%07d_LAST_n0_t%s%s_%s_%s.fits', SerialNum, MountGeoName, CameraObj.CamGeoName, ImageDate, CameraObj.ImType);
%    CameraObj.LastImageSearialNum = SerialNum;

   % Construct header
   Header = CameraObj.updateHeader;

   % Write fits
   FITS.write(single(CameraObj.Handle.LastImage), CameraObj.LastImageName,'Header',Header,'DataType','single');

   CameraObj.LogFile.writeLog(sprintf('%s is written', CameraObj.LastImageName))


end
