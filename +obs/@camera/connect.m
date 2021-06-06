function CameraObj=connect(CameraObj,CameraAddress,varargin)
    %
    % Example: C.connect(1) % single number interpreted as CameraNumSDK
    %          C.connect; % like previous
    %          C.connect([1 1 3]);

    if nargin<2
        CameraAddress = [];
    end

    InPar = inputParser;
    addOptional(InPar,'MountH',[]);   % Mount Handle | [] | 'messenger'
    addOptional(InPar,'FocuserH',[]); % Focuser Handle | []
    addOptional(InPar,'ConstructMessenger',false);
    parse(InPar,varargin{:});
    InPar = InPar.Results;

    ConfigBaseName  = 'config.camera';
    PhysicalKeyName = 'CameraName';
    % list of properties to update according to Config file content
    ListProp        = {'NodeNumber',...
                       'MountNumber',...
                       'CameraType',...
                       'CameraModel',...
                       'CameraName',...
                       'CameraNumber',...
                       'CameraPos',...
                       'ReadMode',...
                       'Offset',...
                       'Gain',...
                       'Binning',...
                       'Filter',...
                       'LogFileDir'};

    if isempty(CameraAddress)
        CameraAddress = 1;
    end

    ConfigStruct = [];
    if isnumeric(CameraAddress) && numel(CameraAddress)==1
        % CameraAddress is interpreted as CamerNumSDK
        % A single camera is connected
        Ncam = 1;
        AllCamNumSDK = CameraAddress;
        AllCamName   = {};

    else
        if isnumeric(CameraAddress) && numel(CameraAddress)==3
            % CameraAddress is [Node, Mount, Number]
            % A single camera is connected
            % Read config file
            [ConfigStruct] = readConfig(CameraObj,CameraAddress,...
                            ConfigBaseName,PhysicalKeyName);

            [AllCamName,AllCamNumSDK]=obs.camera.identify_all_cameras(ConfigStruct.CameraName);
            AllCamName = AllCamName(AllCamNumSDK);
            Ncam       = 1;



        elseif ischar(CameraAddress)
            switch lower(CameraAddress)
                case 'all'
                    % connect to all available cameras

                    % return a list of all camera names
                    AllCamName = obs.camera.identify_all_cameras;

                    % open all cameras
                    Ncam = numel(AllCamName);
                    AllCamNumSDK = (1:1:Ncam).';

                otherwise
                    error('Unknwon CameraAdress option');
            end
        else
            error('Unknwon CameraAdress option');
        end
    end
    % Now we have
    % AllCamName
    % AllCamNumSDK
    % Ncam

    if numel(CameraObj)~=Ncam
        error('Number of identified camera is %d while number of elements in object is %d - must be equal',numel(CameraObj),Ncam);
    end

    for Icam=1:1:Ncam
        % connect to each camera

        % connect camera
        CameraObj(Icam).CameraNumSDK = AllCamNumSDK(Icam);
        switch lower(CameraObj(Icam).CameraType)
            case 'qhy'
                CameraObj(Icam).Handle = inst.QHYccd(CameraObj(Icam).CameraNumSDK);
            case 'zwo'
                CameraObj(Icam).Handle = inst.ZWOASICamera(CameraObj(Icam).CameraNumSDK);
            otherwise
                error('Unknown CameraType option');
        end

        Success = CameraObj(Icam).Handle.connect(CameraObj(Icam).CameraNumSDK);
        if Success
            CameraObj(Icam).IsConnected = true;
        else
            CameraObj(Icam).IsConnected = false;
        end

        CameraObj(Icam).CameraName = CameraObj(Icam).Handle.CameraName;

        % populate the rest of the parameters from the config file

        % load physical config file
        ConfigFileNamePhysical = sprintf('config.%s.txt',CameraObj(Icam).CameraName);
        ConfigPhysical         = CameraObj.loadConfiguration(ConfigFileNamePhysical, false);

        % load corresponding logical config file
        % search in all config files
        Result = CameraObj.search_key_in_all_config(ConfigBaseName,{'CameraName','NodeNumber','MountNumber','CameraNumber'});
        Ires = find(strcmp(CameraObj(Icam).CameraName,{Result.CameraName}));

        if isempty(Ires)
            % config file not found
            ConfigStruct = [];
            Address = [NaN NaN NaN];
            CameraObj(Icam).ConfigStruct = ConfigPhysical;
            CameraObj(Icam).ConfigStruct.ProjectName = 'LAST';
            CameraObj(Icam).ConfigStruct.NodeNumber  = 0;
            CameraObj(Icam).ConfigStruct.MountNumber = 0;
            CameraObj(Icam).ConfigStruct.CameraNumber = 0;
            CameraObj(Icam).ConfigStruct.Filter = 'Unknown';
            CameraObj(Icam).ConfigStruct.DataDir = '';
            CameraObj(Icam).ConfigStruct.BaseDir = pwd;
            [Dummy, Host] = system('hostname');
            CameraObj(Icam).ConfigStruct.DarkDBDir = ['/', Host(1:6), '/data/ServiceImages/darkDB'];
            CameraObj(Icam).ConfigStruct.FlatDBDir = ['/', Host(1:6), '/data/ServiceImages/flatDB'];
            warning('Checking unknown camera - images will be saved on current directory. Delete after use')

        elseif  numel(Ires)>1
            error('More than one config file with the same camera name was found');

        else
            Address = [Result(Ires).NodeNumber, Result(Ires).MountNumber, Result(Ires).CameraNumber];
            [ConfigStruct] = getConfigStruct(CameraObj(Icam),Address,ConfigBaseName,PhysicalKeyName);
            CameraObj(Icam).ConfigStruct = ConfigStruct;
            CameraObj(Icam).updatePropFromConfig(ListProp,CameraObj(Icam).ConfigStruct);
        end



        % treat LogFile
        CameraObj(Icam).LogFile = logFile;
        if isempty(CameraObj(Icam).LogFileDir)
            % do not write logFile
            CameraObj(Icam).LogFile.FileNameTemplate = '';    
        else
            % write logFile
            CameraObj(Icam).LogFile.Dir      = CameraObj(Icam).LogFileDir;
            CameraObj(Icam).LogFile.logOwner = sprintf('Camera_%d_%d_%d',Address);
        end
        % write logFile
        if isempty(ConfigStruct)
            CameraObj(Icam).LogFile.writeLog(sprintf('Attempt to connect to camera'));
        else
            CameraObj(Icam).LogFile.writeLog(sprintf('Attempt to connect to camera %s',ConfigStruct.CameraName));
        end


        % Handles for external objects
        CameraObj(Icam).HandleMount   = InPar.MountH;
        CameraObj(Icam).HandleFocuser = InPar.FocuserH;

        if InPar.ConstructMessenger && isempty(CameraObj(Icam).HandleMount)
            % if user didn't provide handles
            % try to see if there is IP/Port info in Config file

            % check if config is available
            Port = NaN;
            if ~isnan(CameraObj(Icam).MountNumber)

                DestinationIP   = CameraObj.ConfigMount.MountHostIP;
                DestinationPort = obs.remoteClass.construct_port_number('mount', CameraObj(Icam).MountNumber,CameraObj(Icam).CameraNumber);
                LocalPort       = obs.remoteClass.construct_port_number('camera',CameraObj(Icam).MountNumber,CameraObj(Icam).CameraNumber);

                RemoteName = 'M';
                MsgObj                    = obs.remoteClass(RemoteName,DestinationIP,DestinationPort,LocalPort);
                MsgObj.Messenger.CallbackRespond = false;
                MsgObj.Messenger.connect;
                CameraObj.HandleMount     = MsgObj;
            end
        end

        % verify connection and write log
        if isnan(CameraObj(Icam).Temperature)
            LogMsg = sprintf('Was not able to connect to camera %d',Icam);
            CameraObj(Icam).IsConnected = false;
        else
            LogMsg = sprintf('Camera %d connected sucssefuly',Icam);
            CameraObj(Icam).IsConnected = true;
        end
        CameraObj(Icam).LogFile.writeLog(LogMsg);
        if CameraObj(Icam).Verbose
            fprintf('%s\n',LogMsg);
        end
    end

end
