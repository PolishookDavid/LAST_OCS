function connect(MountObj)
% Connect the mount object to the physical mount,
%  open a logFile object, and import the associated configuration file.
%
% Example: M.connect()

    % Open the logFile (what do we want to do here? Open a different log
    %  file for each device, or one for the whole unitCS?)
    if isempty(MountObj.LogFile)
%         % create a logFile, but with empty TemplateFileName so no
%         % writing is performed
%         MountObj.LogFile = logFile;
%         MountObj.LogFile.FileNameTemplate = [];
%         % .Dir missing in Astropack's LogFile
%         MountObj.LogFile.LogPath = '~';
    else
%         MountObj.LogFileDir = ConfigStruct.LogFileDir;
%         % .logOwner missing in Astropack's LogFile
%         % MountObj.LogFile.logOwner = sprintf('mount_%d_%d',MountAddress);
%         % .Dir missing in Astropack's LogFile
%         MountObj.LogFile.LogPath = ConfigStruct.LogFileDir;
    end

    % write logFile
    MountObj.report(sprintf('Trying to connect to mount %s at %s\n',...
                            MountObj.MountName,MountObj.PhysicalPort));
    
    % DUBIOUS replacement of original code for PhysicalPort vs. MountIP
    %  which defied abstraction. CHECK.
    if isSerialPort(MountObj.PhysicalPort)
        MountPort = MountObj.PhysicalPort;
    elseif isPCIusb(MountObj.PhysicalPort)
        MountPort = idpath_to_port(MountObj.PhysicalPort);
    elseif isIPnum(MountObj.PhysicalPort)
        % notably for iOptron
        MountPort = MountObj.PhysicalPort;
    else
        error('PhysicalPort not legal for the mount')
    end
    
    try
        Success = MountObj.Handle.connect(MountPort);
        MountObj.IsConnected = Success;
    catch
        MountObj.reportError('Mount object is not able to connect');
        Success=false;
    end

    if Success
        MountObj.report('Mount is connected successfully\n')
        % load configuration
        MountObj.loadConfig(MountObj.configFileName('connect'))
        % Mount location coordinates and UTC
        if (MountObj.TimeFromGPS)
            % Take from GPS
            if isfield(MountObj.Handle.FullStatus,'Lon')
                MountObj.ObsLon = MountObj.Handle.FullStatus.Lon;
            else
                MountObj.reportError('Lon is not available');
            end
            if isfield(MountObj.Handle.FullStatus,'Lat')
                MountObj.ObsLat = MountObj.Handle.FullStatus.Lat;
            else
                MountObj.reportError('Lat is not available');
            end
        else
            % coordinates from Config - already taken, or default -
            %  don't bother to trap if all fields are available
        end
    else
        MountObj.reportError('Mount was not connected successfully\n')
    end

end
