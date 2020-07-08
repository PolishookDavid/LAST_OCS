function success=connect(MountObj)
% connect to a focus motor on the specified Port, try all ports if
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
        MountObj.MountUniqueName =         util.readSystemConfigFile('MountUniqueName');
        MountObj.MountGeoName =            util.readSystemConfigFile('MountGeoName');
        MountObj.TelescopeEastUniqueName = util.readSystemConfigFile('TelescopeEastUniqueName');
        MountObj.TelescopeWestUniqueName = util.readSystemConfigFile('TelescopeWestUniqueName');

        % Mount location coordinates and UTC
        if (MountObj.TimeFromGPS)
           % Take from GPS
           MountObj.MountCoo.ObsLon = MountObj.MouHn.fullStatus.Lon;
           MountObj.MountCoo.ObsLat = MountObj.MouHn.fullStatus.Lat;
        else
           % Take coordinates from computer
           MountObj.MountCoo.ObsLon = util.readSystemConfigFile('MountLongitude');
           MountObj.MountCoo.ObsLat = util.readSystemConfigFile('MountLatitude');
           MountObj.MountCoo.ObsHeight = util.readSystemConfigFile('MountHeight');
           MountObj.MountPos = [MountObj.MountCoo.ObsLon MountObj.MountCoo.ObsLat MountObj.MountCoo.ObsHeight];
           % Update UTC clock on mount
           MountObj.MouHn.MountUTC = 'dummy';
        end

        % Read mount parking position from the config file
        MountObj.ParkPos = [util.readSystemConfigFile('MountParkAz'), util.readSystemConfigFile('MountParkAlt')];

        % Read Alt minimal limitation from the config file
        MountObj.MinAlt = util.readSystemConfigFile('MountMinAlt');

        % Read Alt minimal limitation map from the config file
        MountObj.MinAzAltMap = util.readSystemConfigFile('MountMinAzAltMap');
        
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
       Text = sprintf("Mount %s is disconnected", util.readSystemConfigFile('MountGeoName'));
       MountObj.LastError = Text;
    end

end
