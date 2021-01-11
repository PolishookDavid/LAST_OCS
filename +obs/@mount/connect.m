function success=connect(MountObj)
% connect to a mount on the specified Port, try all ports if
%  Port omitted

   % Construct directory for log file
   DirName = obs.util.config.constructDirName('log');
   cd(DirName);

%    % Opens Log for the mount
%    MountObj.LogFile = logFile;
%    MountObj.LogFile.Dir = DirName;
%    MountObj.LogFile.FileNameTemplate = 'LAST_%s.log';
%    MountObj.LogFile.logOwner = sprintf('%s.%s.%s_Mount', ...
%                                        obs.util.config.readSystemConfigFile('ObservatoryNode'),...
%                                        obs.util.config.readSystemConfigFile('MountGeoName'),...
%                                        obs.util.config.readSystemConfigFile('CamGeoName'), DirName(end-7:end));
           
   % Read configure files:
   ConfigNode=obs.util.config.read_config_file('/home/last/config/config.node.txt');
   ConfigMount=obs.util.config.read_config_file('/home/last/config/config.mount.txt');
   ConfigCam=obs.util.config.read_config_file('/home/last/config/config.camera.txt');
   
   % Opens Log for the mount
   MountObj.LogFile = logFile;
   MountObj.LogFile.Dir = DirName;
   MountObj.LogFile.FileNameTemplate = '%s';
   MountObj.LogFile.logOwner = obs.util.config.constructImageName('LAST', ...
                                                           num2str(ConfigNode.ObservatoryNode),...
                                                           num2str(ConfigMount.MountGeoName),...
                                                           '', datestr(now,'yyyymmdd.HHMMSS.FFF'), ...
                                                           CameraObj.Filter,...
                                                           '',      '',     'log',   '',         '',        '1',       'log');
% legend:                                                  FieldID, ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, ImageFormat
                                   
                              
                                   
    MountObj.LogFile.writeLog('Connecting to mount.')

    % Connect to the mount using its IP address
%    MountObj.IPaddress = obs.util.config.readSystemConfigFile('MountIPaddress');
    MountObj.IPaddress = ConfigMount.MountIPaddress;
    success = MountObj.Handle.connect(MountObj.IPaddress);
    MountObj.IsConnected = success;
    
    if success
       MountObj.LogFile.writeLog('Mount is connected.')
        % Naming of instruments
        MountObj.MountType = MountObj.Handle.MountType;
        MountObj.MountModel = MountObj.Handle.MountModel;
        % Read mount unique and Geo name from config file
%         MountObj.MountUniqueName =         obs.util.config.readSystemConfigFile('MountUniqueName');
%         MountObj.MountGeoName =            obs.util.config.readSystemConfigFile('MountGeoName');
%         MountObj.TelescopeEastUniqueName = obs.util.config.readSystemConfigFile('TelescopeEastUniqueName');
%         MountObj.TelescopeWestUniqueName = obs.util.config.readSystemConfigFile('TelescopeWestUniqueName');
        MountObj.MountUniqueName =         ConfigMount.MountUniqueName;
        MountObj.MountGeoName =            ConfigMount.MountGeoName;

        % Mount location coordinates and UTC
        if (MountObj.TimeFromGPS)
           % Take from GPS
           MountObj.MountCoo.ObsLon = MountObj.Handle.FullStatus.Lon;
           MountObj.MountCoo.ObsLat = MountObj.Handle.FullStatus.Lat;
        else
           % Take coordinates from computer
%            MountObj.MountCoo.ObsLon = obs.util.config.readSystemConfigFile('MountLongitude');
%            MountObj.MountCoo.ObsLat = obs.util.config.readSystemConfigFile('MountLatitude');
%            MountObj.MountCoo.ObsHeight = obs.util.config.readSystemConfigFile('MountHeight');
           MountObj.MountCoo.ObsLon = ConfigMount.MountLongitude;
           MountObj.MountCoo.ObsLat = ConfigMount.MountLatitude;
           MountObj.MountCoo.ObsHeight = ConfigMount.MountHeight;
           MountObj.MountPos = [MountObj.MountCoo.ObsLon MountObj.MountCoo.ObsLat MountObj.MountCoo.ObsHeight];
           % Update UTC clock on mount
           MountObj.Handle.MountUTC = 'dummy';
        end

        % Read mount parking position from the config file
%        MountObj.ParkPos = [obs.util.config.readSystemConfigFile('MountParkAz'), obs.util.config.readSystemConfigFile('MountParkAlt')];
        MountObj.ParkPos = [ConfigMount.MountParkAz, ConfigMount.MountParkAlt)];

        % Read Alt minimal limitation from the config file
%        MountObj.MinAlt = obs.util.config.readSystemConfigFile('MountMinAlt');
        MountObj.MinAlt = ConfigMount.MountMinAlt;

        % Read Alt minimal limitation map from the config file
%        MountObj.MinAzAltMap = obs.util.config.readSystemConfigFile('MountMinAzAltMap');
        MountObj.MinAzAltMap = ConfigMount.MountMinAzAltMap;
        
        MountObj.LogFile.writeLog('~~~~~~~~~~~~~~~~~~~~~~')
        MountObj.LogFile.writeLog('Details:')
        MountObj.LogFile.writeLog(sprintf('Type: %s',MountObj.MountType))
        MountObj.LogFile.writeLog(sprintf('Model: %s',MountObj.MountModel))
        MountObj.LogFile.writeLog(sprintf('UniqueName: %s',MountObj.MountUniqueName))
        MountObj.LogFile.writeLog(sprintf('GeoName: %s',MountObj.MountGeoName))
        MountObj.LogFile.writeLog(sprintf('Minimal Alt: %.1f',MountObj.MinAlt))
        MountObj.LogFile.writeLog(sprintf('Park position: %.1f %.1f',MountObj.ParkPos(1), MountObj.ParkPos(2)))
        MountObj.LogFile.writeLog('~~~~~~~~~~~~~~~~~~~~~~')
    else
%       Text = sprintf("Mount %s is disconnected", obs.util.config.readSystemConfigFile('MountGeoName'));
       Text = sprintf("Mount %s is disconnected", ConfigMount.MountGeoName);
       MountObj.LastError = Text;
    end

end
