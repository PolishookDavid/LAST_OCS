function connect(MountObj,MountAddress,MountType)
    % Connect a mount abstraction object
    % Description: Connect the mount object to the actual mount,
    %              open a logFile object, and read the
    %              configuration files related to the mount.
    % Input  : - Mount object
    %          - This can be:
    %            1. A mount address which is a vector of
    %               [NodeNumber, MountNumber]
    %            2. A mount configuration file name (string).
    %            3. Empty [default]. In this case, some default
    %               values will be used.
    %          - MountType : class name of the mount driver, e.g
    %                  'XerxesMount' | 'iOptronCEM120' (without 'inst.'
    %                      prefix)
    %            If not given will attempt to read from Config
    % Example: M.connect([],'XerxesMount')

    ConfigBaseName  = 'config.mount';
    PhysicalKeyName = 'MountName';
    ListProp        = {'NodeNumber',...
                       'MountType',...
                       'MountModel',...
                       'MountName',...
                       'MountNumber',...
                       'ObsLon',...
                       'ObsLat',...
                       'ObsHeight',...
                       'LogFileDir'};


    if nargin<2
        MountAddress = [];
    end

    if nargin==3
        MountObj.MountType = inst.(MountType);
    end

    if ischar(MountAddress)
        MountAddress = [NaN NaN];
    else
        if numel(MountAddress)~=2
            MountAddress = [NaN NaN];
        end
    end

    if any(isnan(MountAddress))
        ConfigStruct   = [];
        ConfigLogical  = [];
        ConfigPhysical = [];
    else
        [ConfigStruct] = getConfigStruct(MountObj,...
                            MountAddress,...
                            ConfigBaseName,PhysicalKeyName);                
        MountObj.ConfigStruct = ConfigStruct;               
        MountObj = updatePropFromConfig(MountObj,ListProp,MountObj.ConfigStruct);
    end

    % Open the logFile
    if isempty(MountObj.LogFile) || isempty(ConfigStruct)
        % create a logFile, but with empty TemplateFileName so no
        % writing is performed
        MountObj.LogFile = logFile;
        MountObj.LogFile.FileNameTemplate = [];
        % .Dir missing in Astropack's LogFile
        MountObj.LogFile.LogPath = '~';
    else
        MountObj.LogFileDir = ConfigStruct.LogFileDir;
        % .logOwner missing in Astropack's LogFile
        % MountObj.LogFile.logOwner = sprintf('mount_%d_%d',MountAddress);
        % .Dir missing in Astropack's LogFile
        MountObj.LogFile.LogPath = ConfigStruct.LogFileDir;
    end

    % write logFile
    MountObj.LogFile.write(sprintf('Connecting to mount address: %d %d %d / Name: %s',MountAddress,MountObj.MountName));
    
    % DUBIOUS replacement of original code for PhysicalPort vs. MountIP
    %  which defied abstraction. CHECK.
    if isSerialPort(MountObj.ConfigStruct.PhysicalPort)
        MountPort = MountObj.ConfigStruct.PhysicalPort;
    elseif isPCIusb(MountObj.ConfigStruct.PhysicalPort)
        MountPort = idpath_to_port(MountObj.ConfigStruct.PhysicalPort);
    elseif isIPnum(MountObj.ConfigStruct.PhysicalPort)
        % notably for iOptron
        MountObj.MountIP = MountObj.ConfigStruct.PhysicalPort;
        MountPort = MountObj.MountIP;
    else
        error('PhysicalPort not legal for the mount')
    end
    
    Success = MountObj.Handle.connect(MountPort);
    MountObj.IsConnected = Success;

    if Success
        MountObj.LogFile.write('Mount is connected successfully')

        %MountObj.MountModel = MountObj.Handle.MountModel;

        % Mount location coordinates and UTC
        if (MountObj.TimeFromGPS)
            % Take from GPS
            if isfield(MountObj.Handle.FullStatus,'Lon')
                MountObj.ObsLon = MountObj.Handle.FullStatus.Lon;
            else
                MountObj.LogFile.write('Lon is not available');
                error('Lon is not available');
            end
            if isfield(MountObj.Handle.FullStatus,'Lat')
                MountObj.ObsLat = MountObj.Handle.FullStatus.Lat;
            else
                MountObj.LogFile.write('Lat is not available');
                error('Lat is not available');
            end
        else
            % coordinates from Config - already taken, or default -
            %  don't bother to trap if all fields are available
        end
    else
        MountObj.LogFile.write('Mount was not connected successfully')
        MountObj.LastError = sprintf("Mount %s is disconnected", num2str(ConfigMount.MountNumber));
    end

end
