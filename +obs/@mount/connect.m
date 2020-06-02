function success=connect(MountObj)
% connect to a focus motor on the specified Port, try all ports if
%  Port omitted
    success = MountObj.MountDriverHndl.connect;
    MountObj.lastError = MountObj.MountDriverHndl.lastError;
%     if (success) % DP: WHY the mount driver connect method returns zero??? 2020, Jun 1
        MountObj.Port = MountObj.MountDriverHndl.Port;
        % Naming of instruments
        MountObj.MountType = MountObj.MountDriverHndl.MountType;
        MountObj.MountModel = MountObj.MountDriverHndl.MountModel;
        % Read mount unique and Geo name from config file
        MountObj.MountUniqueName =         util.readSystemConfigFile('MountUniqueName');
        MountObj.MountGeoName =            util.readSystemConfigFile('MountGeoName');
        MountObj.TelescopeEastUniqueName = util.readSystemConfigFile('TelescopeEastUniqueName');
        MountObj.TelescopeWestUniqueName = util.readSystemConfigFile('TelescopeWestUniqueName');

        % Mount location coordinates and UTC
        if (MountObj.TimeFromGPS)
           % Take from GPS
           MountObj.MountCoo.ObsLon = MountObj.MountDriverHndl.fullStatus.Lon;
           MountObj.MountCoo.ObsLat = MountObj.MountDriverHndl.fullStatus.Lat;
        else
           % Take from computer
           MountObj.MountCoo.ObsLon = util.readSystemConfigFile('MountLongitude');
           MountObj.MountCoo.ObsLat = util.readSystemConfigFile('MountLatitude');
           MountObj.MountCoo.ObsHeight = util.readSystemConfigFile('MountHeight');
           MountObj.MountDriverHndl.MountUTC = 'dummy';
        end

        % Read mount parking position from the config file
        MountObj.ParkPos = [util.readSystemConfigFile('MountParkAz'), util.readSystemConfigFile('MountParkAlt')];

        % Read Alt minimal limitation from the config file
        MountObj.MinAlt = util.readSystemConfigFile('MountMinAlt');

        % Read Alt minimal limitation map from the config file
        MountObj.MinAzAltMap = util.readSystemConfigFile('MountMinAzAltMap');
%     end

end
