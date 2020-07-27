function success=connect(MountObj)
% connect to a mount on the specified Port, try all ports if
%  Port omitted
    MountObj.LogFile.writeLog('Connecting to mount.')
    success = MountObj.MouHn.connect;
    MountObj.IsConnected = success;
    
    if success
       MountObj.LogFile.writeLog('Mount is connected.')
        % Naming of instruments
        MountObj.MountType = MountObj.MouHn.MountType;
        MountObj.MountModel = MountObj.MouHn.MountModel;
        % Read mount unique and Geo name from config file
        MountObj.MountUniqueName =         obs.util.readSystemConfigFile('MountUniqueName');
        MountObj.MountGeoName =            obs.util.readSystemConfigFile('MountGeoName');
        MountObj.TelescopeEastUniqueName = obs.util.readSystemConfigFile('TelescopeEastUniqueName');
        MountObj.TelescopeWestUniqueName = obs.util.readSystemConfigFile('TelescopeWestUniqueName');

        % Mount location coordinates and UTC
        if (MountObj.TimeFromGPS)
           % Take from GPS
           MountObj.MountCoo.ObsLon = MountObj.MouHn.fullStatus.Lon;
           MountObj.MountCoo.ObsLat = MountObj.MouHn.fullStatus.Lat;
        else
           % Take coordinates from computer
           MountObj.MountCoo.ObsLon = obs.util.readSystemConfigFile('MountLongitude');
           MountObj.MountCoo.ObsLat = obs.util.readSystemConfigFile('MountLatitude');
           MountObj.MountCoo.ObsHeight = obs.util.readSystemConfigFile('MountHeight');
           MountObj.MountPos = [MountObj.MountCoo.ObsLon MountObj.MountCoo.ObsLat MountObj.MountCoo.ObsHeight];
           % Update UTC clock on mount
           MountObj.MouHn.MountUTC = 'dummy';
        end

        % Read mount parking position from the config file
        MountObj.ParkPos = [obs.util.readSystemConfigFile('MountParkAz'), obs.util.readSystemConfigFile('MountParkAlt')];

        % Read Alt minimal limitation from the config file
        MountObj.MinAlt = obs.util.readSystemConfigFile('MountMinAlt');

        % Read Alt minimal limitation map from the config file
        MountObj.MinAzAltMap = obs.util.readSystemConfigFile('MountMinAzAltMap');
        
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
       Text = sprintf("Mount %s is disconnected", obs.util.readSystemConfigFile('MountGeoName'));
       MountObj.LastError = Text;
    end

end
