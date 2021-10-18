function connect(MountObj)
% This method is responsible only for loading the configuration, and is
%  called by the driver connect method itself (superclass invocation) only
%  if physical connection is successful.

    MountObj.report('Loading post connection configuration for Mount %s\n',...
                     MountObj.Id)
    % load configuration
    MountObj.loadConfig(MountObj.configFileName('connect'))
    % Mount location coordinates and UTC
    if (MountObj.TimeFromGPS)
        % Take from GPS
        if isfield(MountObj.FullStatus,'Lon')
            MountObj.ObsLon = MountObj.FullStatus.Lon;
        else
            MountObj.reportError('Lon is not available');
        end
        if isfield(MountObj.FullStatus,'Lat')
            MountObj.ObsLat = MountObj.FullStatus.Lat;
        else
            MountObj.reportError('Lat is not available');
        end
    else
        % coordinates from Config - already taken, or default -
        %  don't bother to trap if all fields are available
    end

end
