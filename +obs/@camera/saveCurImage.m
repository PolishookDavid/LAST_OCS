function saveCurImage(CameraObj)
% Save last image to disk according the user's settings

   % Construct directory name to save image in
   DirName = obs.util.config.constructDirName('raw');
   cd(DirName);
   CameraObj.LogFile.writeLog(sprintf('cd %s',DirName))

   ConfigNode=obs.util.config.read_config_file('/home/last/config/config.node.txt');
   ConfigMount=obs.util.config.read_config_file('/home/last/config/config.mount.txt');

   % Construct image name   
   ProjectName = 'LAST';
   ImageDate = datestr(CameraObj.TimeStart,'yyyymmdd.HHMMSS.FFF');
   % Old config file reading (before Dec 2020):
%    ObservatoryNode = obs.util.config.readSystemConfigFile('ObservatoryNode');
%    MountGeoName = obs.util.config.readSystemConfigFile('MountGeoName');
   % New config file reading (after Dec 2020):
   ObservatoryNode = ConfigNode.ObservatoryNode;
   MountGeoName = ConfigMount.MountGeoName;

   FieldID = [CameraObj.Object,'.',CameraObj.CCDnum];
   ImLevel = 'raw';
   ImSubLevel = 'n';
   ImProduct = 'im';
   ImVersion = '1';

   % Image name legend:    LAST.Node.mount.camera_YYYYMMDD.HHMMSS.FFF_Filter_CCDnum_ImType.fits
   % Image name example:   LAST.1.1.e_20200603.063549.030_clear_0_science.fits
   CameraObj.LastImageName = obs.util.config.constructImageName(ProjectName, ObservatoryNode, MountGeoName, CameraObj.CamGeoName, ImageDate, CameraObj.Filter, FieldID, CameraObj.ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, CameraObj.ImageFormat);

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
