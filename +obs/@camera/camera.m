% Abstraction class for camera
% Package: +obs.camera
% Description: This abstraction class support and opperate the driver
%              classes for either the QHY or ZWO detectors.
% Some basic examples:
%   C = obs.camera('QHY');  % create an empty camera object for a QHY device
%   C.connect               % connect the camera
%   C.connect([1 1 3])
%
%
%   C.ExpTime = 1;          % set the Exposure time to 1s
%   C.takeExposure;         % take a single exposure. Save and display the image
%
%   % delete the object
%   C.disconnect
%   clear C


classdef camera < obs.LAST_Handle
 
    properties
        ExpTime double         = 1;           % Exposure time [s]
        Temperature double     = NaN;         % Temperature of the camera
        ImType char            = 'sci';       % The image type: science, flat, bias, dark
        Object char            = '';          % The name of the observed object/field
    end
    properties(GetAccess = public, SetAccess = private)
        Status char            = 'unknown';   % The status of the camera: idle, exposing, reading, unknown
        CoolingPower double    = NaN;         % The cooling power precentage of the camera
        LastImageName char     = '';          % The name of the last image 
        LastImage                             % A matrix of the last image
        LastImageSaved logical = false;       % a flag indicating if the last image was saved.
    end
    
    properties(Hidden)
        Filter char            = '';          % Filter Name % not in driver
        Pos double             = NaN;         % Focuser position
        LastPos double         = NaN;         % focuser last position
        FocuserStatus          = [];          % focuser status
    end
    
    % camera setup
    properties(Hidden)
        ReadMode(1,1) double   = 1;           % Camera readout mode. QHY deault of 1 determines a low readnoise
        Offset(1,1) double     = 3;           % The bias level mode of the camera. QHY default is 3
        Gain(1,1) double       = 0;           % The gain of the camera. QHY default is 0
        Binning(1,2) double    = [1,1];       % The binning of the pixels.
        %ROI                          % beware - SDK does not provide a getter for it, go figure
        CoolingStatus char     = 'unknown';
    end
    
    % limits
    properties(Hidden)    
        MaxExpTime    = 300;        % Maximum exposure time in seconds
        
    end
    
    % Camera ID
    properties(Hidden, GetAccess = public, SetAccess = public)
        NodeNumber double      = NaN;
        MountNumber double     = NaN;
        CameraType char        = 'QHY';
        CameraModel char       = 'QHY600M-PH';
        CameraName char        = '';
        CameraNumSDK double                         % Camera number in the SDK
        CameraNumber double    = NaN                %  1       2      3      4
        CameraPos char         = '';                % 'NE' | 'SE' | 'SW' | 'NW'
        AllCamNames cell       = {};                % A list of all identified cameras - populated on first connect
    end
        
    properties(Hidden)
    
        IsConnected         = false;       % A flag marking if the computer code is connected to the camera    
        LogFile             = '';          % FileName. If not provided, then if LogFileDir is not available than do not write LogFile.
        LogFileDir;
        % In LAST_Handle
        %Config char         = '';         % config file name
        %ConfigStruct struct = struct;     % structure containing the configuration parameters
        ConfigHeader struct = struct;     % structure containing additional header keywords with constants
        ConfigMount struct  = struct;     % structure containing the mount configuration parameters
    end
    
    properties(Hidden, GetAccess = public, SetAccess = private)
        % Start time and end time of the last integration.
        TimeStart double     = [];
        TimeEnd double       = [];
        %TimeStartPrev double = [];  % This is the start time as obtained from the camera immidetly after the camera return to idle state.
        %TimeEndtPrev double  = [];
    end
    
    % save
    properties(Hidden)
        SaveOnDisk logical   = true; %false;   % A flag marking if the images should be wriiten to the disk after exposure
        ImageFormat char     = 'fits';    % The format of the written image
        SaveWhenIdle logical = true;      % will save LastImage even if camera is not idle
    end
    
    % display
    properties(Hidden)
        Display              = 'ds9';   % 'ds9' | 'matlab' | ''
        Frame double         = [];
        DisplayZoom double   = 0.08;    % ds9 zoom
        DivideByFlat logical = false;    % subtract dark and divide by flat before dispaly
    end
    
        
        
        %DisplayMatlabFig = 0; % Will be updated after first image  % When presenting image in matlab, on what figure number to present
        %DisplayAllImage = true;   % Display the entire image, using ds9.zoom
        %DisplayZoomValueAllImage = 0.08;  % Value for ds9.zoom, to present the entire image
        %DisplayReducedIm = true;   % Remove the dark and flat field before display
        %CCDnum = 0;         % ????   % Perhaps obselete. Keep here until we sure it should be removed
	
   
    
    properties (Hidden,Transient)
        Verbose logical    = true;
        
        Handle;           % Handle to camera driver class
        HandleMount;      % Handle to mount driver class
        HandleFocuser;    % Handle to focuser driver class
        
        ReadoutTimer;     % A timer object to operate after exposure start,  to wait until the image is ready.
        
        LastError = '';   % The last error message
       
        %ImageFormat = 'fits';    % The format of the written image
        %MaxExpTime = 1800;  % Maximum exposure time in seconds
        % The serial number of the last image - not implemented anymore
        %LastImageSearialNum = 0;
        % A flag marking if to print software printouts or not
        
        %pImg  % pointer to the image buffer (can we gain anything in going
              %  to a double buffer model?)
              % Shall we allocate it only once on open(QC), or, like now,
              %  every time we start an acquisition?
              
    end
    
    
    % constructor
    methods
        
        
        function CameraObj=camera(CameraType,Ncam)
            % Camera object constructor
            % This function does not populate the Handle property
            % This is done in the connect stage
            % Input  : - CameraType: 'QHY' | 'ZWO'
            %          - Number of cameras. Default is 1.
            % Example: C=obs.camera('qhy')
            
            DefaultCameraType    = 'QHY';
            
    
            if nargin<2
                Ncam = 1;
                if nargin<1
                    CameraType = DefaultCameraType;
                end
            end
            
            switch lower(CameraType)
                case {'qhy','zwo'}
                    % ok
                otherwise
                    error('Unsupported CameraType option');
            end
            
            CameraObj.CameraType = CameraType;
            
            % read Header comments into ConfigHeader
            ConfigHeaderFileName = 'config.HeaderKeywordComment.txt';
            CameraObj.ConfigHeader = CameraObj.loadConfiguration(ConfigHeaderFileName, false);
            
            
            for Icam=2:1:Ncam
                CameraObj(Icam) = imUtil.util.class.full_copy(CameraObj(1));
            end
            
            %CameraObj(1,Ncam) = CameraObj;
            %for Icam=1:1:Ncam
            %Icam = 1;
            %CameraObj(Icam).CameraType = CameraType;

            % read Header comments into ConfigHeader
            %ConfigHeaderFileName = 'config.HeaderKeywordComment.txt';
            %CameraObj(Icam).ConfigHeader = CameraObj(Icam).loadConfiguration(ConfigHeaderFileName, false);
            %end
            
        end
       
    
    end
    
    % static methods
    methods (Static)
        function [AllCamNames,CameraNumSDK]=identify_all_cameras(CameraName,HandleDriver)
            % Identify all QHY cameras connected to the computer
            % Input  : - CameraName (e.g.., 'QHY367C-e2f51243929ddaaf5').
            %            Default is empty (i.e. return all names).
            %          - Handle driver. If empty, then will be created
            % Output : - A cell array of all identified cameras
            %          - Camera number as identified by the SDK
            % Tested : with QHY/SDK 21-2-1 
            %  https://www.qhyccd.com/file/repository/publish/SDK/210201/sdk_linux64_21.02.01.tgz
            % Example: [AllCamName,CameraNumSDK]=obs.camera.identify_all_cameras(CameraName,HandleDriver)
            
            if nargin<2
                HandleDriver = [];
                if nargin<1
                    CameraName = [];
                end
            end
            
            if isempty(HandleDriver)
                Q       = inst.QHYccd;          % create one camera object and DO NOT connect yet
            end
            Q.verbose   = false;                % optional if you want to see less blabber
            AllCamNames = Q.allQHYCameraNames;

            if nargout>1 && ~isempty(CameraName)
                %CameraNumSDK = find(strcmp(AllCamNames,'QHY367C-e2f51243929ddaaf5'));
                CameraNumSDK = find(strcmp(AllCamNames,CameraName));
            else
                CameraNumSDK = [];
            end
        end
       
        
    end

    
    
    
    % connect
    methods 
        
        
        
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
                
                Sucess = CameraObj(Icam).Handle.connect(CameraObj(Icam).CameraNumSDK);
                if Sucess
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
        
        function CameraObj=connectold(CameraObj,CameraAddress,varargin)    
            % Connect an obs.camera object to a camera
            % Description: Connect the camera to obs.camera object
            %              Performs the following steps:
            %              If the user supplied the camera [Node, Mount, Camera] address
            %              than read the appropriate config files. Read
            %              also the camera name from the config file and
            %              attempt to locate the camera using the
            %              obs.camera.identify_all_cameras command.
            %              If not connect to a camera by its SDK number
            %              (default is 1).
            %              If the config file was read then use it to
            %              populate some properties (e.g., CameraPos,
            %              etc.).
            %              
            %              cooect it.
            %              Else, read the configration file
            %               Read configuration files, identify the camera and
            %              connect using the camera driver.
            %              In addition update the properties (in ListProp)
            %              according to their value in the config files,
            %              and store the config file parameters in the
            %              ConfigStruct property.
            %              In addition define and start the logFile.
            % Input  : - An obs.camera object
            %          - CameraAddress:
            %            1. A mount address which is a vector of
            %               [NodeNumber, MountNumber, CameraNumber]
            %            2. A mount configuration file name (string).
            %            3. An SDK number.
            %            Default is 1.
            %          * Pairs of ...,key,val,... The following keywords are available:
            %            'MountH' - Mount object Handle. Default is [].
            %            'FocuserH' - Focuser object Handle. Default is [].
            


            InPar = inputParser;
            addOptional(InPar,'MountH',[]);
            addOptional(InPar,'FocuserH',[]);
            parse(InPar,varargin{:});
            InPar = InPar.Results;


            if numel(CameraObj)>1
                error('Connect operation works on a single camera at a time');
            end
            
            
            ConfigBaseName  = 'config.camera';
            PhysicalKeyName = 'CameraName';
            % list of properties to update according to Config file content
            ListProp        = {'CameraType',...
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


            if nargin<2
                CameraAddress = 1;
            end
                           
            switch numel(CameraAddress)
                case 3
                    % camera address is [Node, Mount, Telescope]
                    CameraNumSDK  = NaN;
                case 1
                    % camera address is the number of the camera given by
                    % the SDK
                    CameraNumSDK  = CameraAddress;
                    CameraAddress = [NaN NaN NaN];

                otherwise
                    error('Unknown CameraAdress option');
            end

            if isnan(CameraNumSDK)
                % attempt to identify camera number in SDK automatically by
                % name

                % read config file
                % get from Config: CameraName, CameraModel, CameraNumber,
                % CameraLocation
                [ConfigStruct,ConfigLogical,ConfigPhysical,ConfigFileNameLogical,ConfigFileNamePhysical]=readConfig(CameraObj,CameraAddress,...
                                    ConfigBaseName,PhysicalKeyName);
                CameraObj.ConfigStruct = ConfigStruct;
                
                % read config file for mount
                ConfigMount = readConfig(CameraObj,CameraAddress(1:2),...
                                    'config.mount','MountName');
                CameraObj.ConfigMount = ConfigMount;
                
                
                % read config.Header is done upon construction
                CameraName = CameraObj.ConfigStruct.CameraName;
                
                
                % copy to properties should be done only after the camera
                % is connected
                %CameraObj  = updatePropFromConfig(CameraObj,ListProp,ConfigStruct);

                switch lower(CameraObj.CameraType)
                    case 'qhy'
                        if isempty(CameraObj(1).AllCamNames)
                            [AllCamNames,CameraNumSDK] = obs.camera.identify_all_cameras(CameraName);
                            CameraObj(1).AllCamNames = AllCamNames;
                        else
                            fprintf('use existing list of cameras');
                            CameraNumSDK = find(strcmp(CameraObj(1).AllCamNames,CameraName));
                        end
                    case 'zwo'
                        error('ZWO auto camera number option is not supported');
                    otherwise
                        error('Unknown CameraType option');
                end
                 
            end
            CameraObj.CameraNumSDK = CameraNumSDK;
            
            % logFile
            if isempty(CameraObj.LogFileDir)
                % do not write logFile
                CameraObj.LogFile = logFile;
                CameraObj.LogFile.FileNameTemplate = '';
            else
                % write logFile
                LogFileName = CameraObj.LogFile;
                CameraObj.LogFile = logFile;
                CameraObj.LogFile.LogFileDir = CameraObj.LogFileDir;
           
                CameraObj.LogFile.logOwner = sprintf('Camera_%d_%d_%d',CameraAddress);
                if ~isemprt(LogFileName)
                    CameraObj.LogFile.FileNameTemplate = LogFileName;
                end
            end
                
            
            
            % ready to connect to camera

            switch lower(CameraObj.CameraType)
                case 'qhy'
                    CameraObj.Handle=inst.QHYccd(CameraObj.CameraNumSDK);
                case 'zwo'
                    CameraObj.Handle=inst.ZWOASICamera(CameraObj.CameraNumSDK);
                otherwise
                    error('Unknown CameraType option');
            end
            
            % connect to the camera
            Sucess = CameraObj.Handle.connect(CameraNumSDK);
            if Sucess
                CameraObj.IsConnected = true;
            else
                CameraObj.IsConnected = false;
            end
            
            % update the properties in CameraObj according to their values
            % in the ConfigStruct
            % can update properties only after the camera is connected
           % this step will set the gain, offset, readmode
            CameraObj  = updatePropFromConfig(CameraObj,ListProp,CameraObj.ConfigStruct);
            
                
            % copy camera name from handle
            if ~strcmp(CameraObj.CameraName,CameraObj.Handle.CameraName)
                warning('CameraName in abstraction and driver are not the same');
                CameraObj.LogFile.writeLog(sprintf('CameraName in abstract is %s, while in driver is %s',CameraObj.CameraName,CameraObj.Handle.CameraName));
                CameraObj.CameraName = CameraObj.Handle.CameraName;
            end
            
            
            % Handles for external objects
            CameraObj.HandleMount   = InPar.MountH;
            CameraObj.HandleFocuser = InPar.FocuserH;
            
            
            if isempty(CameraObj.HandleMount)
                % if user didn't provide handles
                % try to see if there is IP/Port info in Config file
                
                % check if config is available
                Port = NaN;
                if ~isempty(CameraObj.ConfigMount)
                    if Util.struct.isfield_notempty(CameraObj.ConfigMount,'MountNumber')
                        MountNumber = CameraObj.ConfigMount.MountNumber;
                        
                        DestinationIP   = CameraObj.ConfigMount.MountHostIP;
                        DestinationPort = obs.remoteClass.construct_port_number('mount', MountNumber,CameraObj.CameraNumber);
                        LocalPort       = obs.remoteClass.construct_port_number('camera',MountNumber,CameraObj.CameraNumber);
                        
                        RemoteName = 'M';
                        MsgObj                    = obs.remoteClass(RemoteName,DestinationIP,DestinationPort,LocalPort);
                        MsgObj.Messenger.CallbackRespond = false;
                        MsgObj.Messenger.connect;
                        CameraObj.HandleMount     = MsgObj;
                        
                    end
                end
            end
            
                
            % construct a self message listener    
            %SelfMsg           = obs.util.Messenger('localhost',2013,3013);
            %CameraObj.SelfMsg = 
                

            % verify that the camera is connected
            try
                if ~isnan(CameraObj.Temperature)
                    CameraObj.IsConnected = true;
                    CameraObj.LogFile.writeLog('camera connection ok');
                    
                else
                    CameraObj.IsConnected = false;
                    CameraObj.LogFile.writeLog('Error: camera connection failed');
                    
                end
            catch
                CameraObj.IsConnected = false;
                
                CameraObj.LogFile.writeLog('Error: camera connection failed');
                if CameraObj.Verbose
                    warning('Error: camera connection failed');
                end
                
            end
            
            
            
            
        end

        function Success=disconnect(CameraObj)
           % Close the connection with the camera registered in the current camera object
           
           N = numel(CameraObj);
           for I=1:1:N
               if CameraObj(I).IsConnected

                  % Call disconnect using the camera handle object
                  Success(I) = CameraObj(I).Handle.disconnect;
                  CameraObj(I).IsConnected = ~Success;

                  CameraObj(I).LogFile.writeLog(sprintf('Disconnect CameraName: %s',CameraObj(I).CameraName));
                  if ~isempty(CameraObj(I).LogFile)
                      %CameraObj(I).LogFile.delete;
                  end
               end
           end
        end

        function delete(CameraObj)
            % Delete properly driver object + set IsConnected to false
            
            N = numel(CameraObj);
            for I=1:1:N
                CameraObj(I).Handle.delete;
                CameraObj(I).IsConnected = false;
            end
        end

        % abort 
        % for abort use: CameraObj.Handle.abort
        
    end
            
    % getters/setters
    methods
        % ExpTime
        function Output=get.ExpTime(Obj)
            % getter template
            
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.ExpTime;
                else
                    ErrorStr = 'Can not get ExpTime because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        function set.ExpTime(Obj,InputPar)
            % setter template
            
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    if InputPar>Obj(I).MaxExpTime
                        Obj(I).LogFile.writeLog(sprintf('Error: Requested ExpTime is above MaxExpTime of %f s',Obj(I).MaxExpTime));
                        error('Requested ExpTime is above MaxExpTime of %f s',Obj(I).MaxExpTime);
                    end
                    Obj(I).Handle.ExpTime = InputPar;
                else
                    ErrorStr = 'Can not set ExpTime because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        % Temperature
        function Output=get.Temperature(Obj)
            % getter template
            
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.Temperature;
                else
                    ErrorStr = 'Can not get Tempearture because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);

                end
            end
        end
        
        function set.Temperature(Obj,InputPar)
            % setter template
            
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Obj(I).Handle.Temperature = InputPar;
                else
                    ErrorStr = 'Can not set Tempearture because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);

                end
            end
        end
        
        % Status
        function Output=get.Status(Obj)
            % getter template
            
            if numel(Obj)>1
                error('Status getter works on a single element camera object');
            end
            if Obj.IsConnected 
                Output = Obj.Handle.CamStatus;
            else
                ErrorStr = 'Can not get Status because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
                
            end
        end
        
        % CoolingPower
        function Output=get.CoolingPower(Obj)
            % getter template
            
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.CoolingPower;
                else
                    ErrorStr = 'Can not get CoolingPower because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        % TimeStart
        function Output=get.TimeStart(Obj)
            % getter template
            
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.TimeStart;
                else
                    ErrorStr = 'Can not get TimeStart because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        % TimeEnd
        function Output=get.TimeEnd(Obj)
            % getter template
            
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.TimeEnd;
                else
                    ErrorStr = 'Can not get TimeEnd because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        % LastError
        function Output=get.LastError(Obj)
            % getter template
            
            if numel(Obj)>1
                error('LastError getter works on a single element camera object');
            end
            if Obj.IsConnected 
                Output = Obj.Handle.LastError;
            else
                ErrorStr = 'Can not get LastError because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % LastImage
        function Output=get.LastImage(Obj)
            % getter template
            
            if numel(Obj)>1
                error('LastImage getter works on a single element camera object');
            end
            if Obj.IsConnected 
                Output = Obj.Handle.LastImage;
            else
                ErrorStr = 'Can not get LastImage because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % ReadMode
        function Output=get.ReadMode(Obj)
            % getter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.ReadMode;
                else
                    ErrorStr = 'Can not get ReadMode because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        function set.ReadMode(Obj,InputPar)
            % setter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Obj(I).Handle.ReadMode = InputPar;
                else
                    ErrorStr = 'Can not set ReadMode because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        % Offset
        function Output=get.Offset(Obj)
            % getter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.Offset;
                else
                    ErrorStr = 'Can not get Offset because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        function set.Offset(Obj,InputPar)
            % setter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Obj(I).Handle.Offset = InputPar;
                else
                    ErrorStr = 'Can not set Offset because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        % Gain
        function Output=get.Gain(Obj)
            % getter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.Gain;
                else
                    ErrorStr = 'Can not get Gain because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        function set.Gain(Obj,InputPar)
            % setter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Obj(I).Handle.Gain = InputPar;
                else
                    ErrorStr = 'Can not set Gain because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        % Binning
        function Output=get.Binning(Obj)
            % getter template
            
            if numel(Obj)>1
                error('Binning getter works on a single element camera object');
            end
            if Obj.IsConnected 
                Output = Obj.Handle.Binning;
            else
                ErrorStr = 'Can not get Binning because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        function set.Binning(Obj,InputPar)
            % setter template
            
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Obj(I).Handle.Binning = InputPar;
                else
                    ErrorStr = 'Can not set Binning because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        % CoolingStatus
        function Output=get.CoolingStatus(Obj)
            % getter template
            
            if numel(Obj)>1
                error('CoolingStatus getter works on a single element camera object');
            end
            if Obj.IsConnected 
                Output = Obj.Handle.CoolingStatus;
            else
                ErrorStr = 'Can not get CoolingPower because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        function set.CoolingStatus(Obj,InputPar)
            % setter template
            
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Obj(I).Handle.CoolingStatus = InputPar;
                else
                    ErrorStr = 'Can not set CoolingPower because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        
        % MountHandle
        function set.HandleMount(Obj,InputPar)
            % setter for HandleMount - disconnect Messenger of
            % obs.remoteClass object
           
            if numel(Obj)>1
                error('MountHandle setter works on a single element camera object');
            end
            
            I = 1;
            if isa(Obj(I).HandleMount,'obs.remoteClass')
                % disconnect remote class messenger before insertion
                Obj(I).HandleMount.Messenger.disconnect;
            end
            Obj(I).HandleMount = InputPar;
            
        end
            
        
        % focuser
        function Val=get.Pos(Obj)
            % getters
            
            N = numel(Obj);
            Val = nan(1,N);
            for I=1:1:N
                if ~isempty(Obj(I).HandleFocuser)
                    Val(I) = Obj(I).HandleFocuser.Pos;
                end
            end
        end
        
        function set.Pos(Obj,Val)
            % setters
            
            if ~isempty(Obj.HandleFocuser)
                Obj.HandleFocuser.Pos = Val;
            else
                warning('Can not set focus position because there is no focuser handle');
                Obj.LogFile.writeLog('Can not set focus position because there is no focuser handle');
            end
        end    
        
        function Val=get.LastPos(Obj)
            % getters
            
            N = numel(Obj);
            Val = nan(1,N);
            for I=1:1:N
                if ~isempty(Obj(I).HandleFocuser)
                    Val(I) = Obj(I).HandleFocuser.LastPos;
                end
            end
        end
        
        function Val=get.FocuserStatus(Obj)
            % getters
            
            N = numel(Obj);
            Val = cell(1,N);
            for I=1:1:N
                if ~isempty(Obj(I).HandleFocuser)
                    Val{I} = Obj(I).HandleFocuser.Status;
                end
            end
        end
        
        
        
    end
    
    % callback, timers, wiats
    methods
        function callbackSaveAndDisplay(CameraObj, ~, ~)
            % A callback function: if the camera is idle than stop time,
            % save and display image
            % Input  : - Camera object.
            
            if numel(CameraObj)>1
                error('callbackSaveAndDisplay works on a single element camera object');
            end
            
            
            % This function may work in two manners:
            % 1. Check for idle status - however, this is problematic when
            % taking sequence of imaes.
            % 2. wait for LastImage to be non empty and LastImageSaved to
            % be false.
            
            %size(CameraObj.LastImage)
            if strcmp(CameraObj.Status,'idle') || CameraObj.SaveWhenIdle
            
                % camera is ready
                % Stop timer
                if ~isempty(CameraObj.ReadoutTimer)
                    stop(CameraObj.ReadoutTimer);
                end


                % Save the image according to setting.
                if (CameraObj.SaveOnDisk)
                    CameraObj.saveCurImage;
                end
                CameraObj.LastImageSaved = true;

                % Display the image according to setting.
                if (CameraObj.Display)
                    CameraObj.displayImage;
                end
            end
                   

        end
        
        function Flag = waitFinish(CameraObj)
            % wait until all camera ended exposing, readout, and writing image and returned to idle mode

            WaitTime = 0.01;
            Flag = false;
            
            if CameraObj(1).Verbose
                fprintf('Wait for idle camera\n');
            end
            
            N = numel(CameraObj);
            
            StopWaiting(1,N) = false;
            while ~all(StopWaiting)
                
                pause(WaitTime);
                for I=1:1:N
                    Status = CameraObj(I).Status;
                    switch lower(Status)
                        case {'exposing','reading'}
                            % do nothing - continue waiting

                        case 'idle'
                            StopWaiting(I) = true;

                        otherwise
                            StopWaiting(I) = true;
                            if CameraObj(I).Verbose
                                warning('waitFinish encounter an illegal camera status: %s',Status);
                            end
                            CameraObj(I).LogFile.writeLog(sprintf('waitFinish encounter an illegal camera status: %s',Status));
                    end
                end
                if all(StopWaiting)
                    Flag = true;
                end
                
            end
                        
        end


        function AllFlag = isIdle(CameraObj)
            % Return true (per camera) if camera is idle
            
            N = numel(CameraObj);
            AllFlag = false(1,N);
            for I=1:1:N
                switch lower(CameraObj(I).Status)
                    case 'idle'
                        AllFlag(I) = true;
                    otherwise
                        % do nothing (already false)
                end
            end
            
        end
        
    end
        


    
    % basic functions
    % takeExposure
    methods
        function Flag=takeExposure(CameraObj,ExpTime,Nimages,varargin)
            % Take a single or multiple number of exposures
            % Package: +obs.@mount
            % Input  : - A camera object.
            %          - Exposure time [s]. If provided this will override
            %            the CameraObj.ExpTime, and the CameraObj.ExpTime
            %            will be set to this value.
            %          - Number of images to obtain. Default is 1.
            %          * ...,key,val,...
            %            'WaitFinish' - default is true.
            %            'SaveMode' - default is 2.
            %            'ImType' - default is [].
            %            'Object' - default is [].
            % Output : - Sucess flag.

            
            InPar = inputParser;
%            addOptional(InPar,'WaitFinish',true);
            addOptional(InPar,'WaitFinish',false);
            addOptional(InPar,'ImType',[]);
            addOptional(InPar,'Object',[]);
            addOptional(InPar,'SaveMode',2);
            parse(InPar,varargin{:});
            InPar = InPar.Results;
           
            if InPar.SaveMode==1 && numel(CameraObj)>1
                error('SaveMode=1 is allowed only for a single camera');
            end
            
            
            if ~isempty(InPar.ImType)
                % update ImType
                CameraObj.ImType = InPar.ImType;
            end
            if ~isempty(InPar.Object)
                % update ImType
                CameraObj.Object = InPar.Object;
            end
            
            MinExpTimeForSave = 5;  % [s] Minimum ExpTime below SaveDuringNextExp is disabled
            
           
            if nargin<3
                Nimages = 1;
                if nargin<2
                    ExpTime = CameraObj.ExpTime;
                end
            end
            %ExpTime = CameraObj.ExpTime;
            
            if numel(unique(ExpTime))>1
                error('When multiple cameras all ExpTime need to be the same');
            end
            ExpTime = ExpTime(1);
                        
            if Nimages>1 && ExpTime<MinExpTimeForSave && InPar.SaveMode==2
                error('If SaveMode=2 and Nimages>1 then ExpTime must be above %f s',MinExpTimeForSave);
            end
            
            
            Ncam = numel(CameraObj);
            
            Flag = false;
            if all([CameraObj.IsConnected])
                %Status = CameraObj.Status;
                %SaveDuringNextExp = CameraObj.SaveDuringNextExp;
                
                % take Nimages Exposures
                for Iimage=1:1:Nimages
                    
                    %if isIdle(CameraObj(1))
                    if all(isIdle(CameraObj))
                        % all cameras are idle
                        
                        for Icam=1:1:Ncam
%                             if Icam>1
%                                 if isIdle(CameraObj(Icam))
%                                     % continue
%                                 else
%                                     CameraObj(Icam).waitFinish;
%                                 end
%                             end
                            
                            % Execute exposure command
                            CameraObj(Icam).Handle.takeExposure(ExpTime);
                            if CameraObj(Icam).Verbose
                                fprintf('Start Exposure %d of %d: ExpTime=%.3f s\n',Iimage,Nimages,ExpTime);
                            end
                            CameraObj(Icam).LogFile.writeLog(sprintf('Start Exposure %d of %d: ExpTime=%.3f s',Iimage,Nimages,ExpTime));
                        end  % end of Icam loop
                        
                        switch InPar.SaveMode
                            case 1
                                % start a callback timer that will save
                                % the image immidetly after it is taken

                                % start timer
                                CameraObj(Icam).SaveWhenIdle = false;
                                CameraObj(Icam).ReadoutTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate',...
                                                               'Name', 'camera-timer',...
                                                               'Period', 0.2, 'StartDelay', max(0,ExpTime-1),...
                                                               'TimerFcn', @CameraObj.callbackSaveAndDisplay,...
                                                               'ErrorFcn', 'beep');
                                start(CameraObj(Icam).ReadoutTimer);
                            case 2
                                % save and display while the next image
                                % is taken
                                if Iimage>1
                                    for Icam=1:1:Ncam
                                        if CameraObj(Icam).Verbose
                                            fprintf('Save Image %d of camera %d\n',Iimage-1,Icam);
                                        end
                                        CameraObj(Icam).SaveWhenIdle = true;
                                        %size(CameraObj(Icam).LastImage)
                                        callbackSaveAndDisplay(CameraObj(Icam));
                                        
                                    end
                                end
                        end
                        
                        if InPar.WaitFinish
                            % blocking
                            CameraObj.waitFinish;
                            %size(CameraObj(Icam).LastImage)
                        end

                    else
                        % not idle
                        if all([CameraObj.Verbose])
                            fprintf('Can not take Exposure because at least one camera is not idle\n');
                        end
                        CameraObj.LogFile.writeLog(sprintf('Can not take Exposure because at least one camera is not idle'));
                    end
                         
                end  % end for loop
                
                switch InPar.SaveMode
                    case 2
                        for Icam=1:1:Ncam
                            if CameraObj(Icam).Verbose
                                fprintf('Save Image %d of camera %d\n',Nimages,Icam);
                            end
                            CameraObj(Icam).SaveWhenIdle = true;
                            callbackSaveAndDisplay(CameraObj(Icam));
                            
                        end
                    otherwise
                        % do nothing
                end
                
                Flag = true;
                
            end
            
        end
        
        function Flag=coolingOn(CameraObj)
            % Set cooling on - use Temperature to set temperature
            Flag = false;
            if CameraObj.IsConnected
                Camera.Handle.coolingOn;
                Flag = true;
                CameraObj.LogFile.writeLog('Camera cooling set to on');
            else
                if CameraObj.Verbose
                    fprintf('Camera coolingOn function failed because camera is not connected\n');
                end
                CameraObj.LogFile.writeLog('Camera coolingOn function failed because camera is not connected');
            end
        end
            
        function Flag=coolingOff(CameraObj)
            % Set cooling off
            Flag = false;
            if CameraObj.IsConnected
                Camera.Handle.coolingOff;
                Flag = true;
                CameraObj.LogFile.writeLog('Camera cooling set to off');
            else
                if CameraObj.Verbose
                    fprintf('Camera coolingOff function failed because camera is not connected\n');
                end
                CameraObj.LogFile.writeLog('Camera coolingOff function failed because camera is not connected');
            end
        end
        
        
        function FocRes=focus_camera(CameraObj, varargin)
            % Execute focus loop on current camera
            
            if isempty(CameraObj.HandleMount)
                CameraObj.LogFile.writeLog('HandleMount must be specified while calling focus_camera');
                error('HandleMount must be specified while calling focus_camera');
            end
            if isempty(CameraObj.HandleFocuser)
                CameraObj.LogFile.writeLog('HandleFocuser must be specified while calling focus_camera');
                error('HandleFocuser must be specified while calling focus_camera');
            end
            [FocRes] = obs.util.tools.focus_loop(CameraObj,CameraObj.HandleMount,CameraObj.HandleFocuser,[],varargin{:}); 

           
            
            
        end
        
    end
    
    % communication
    methods
        function [varargout]=commCommand(Obj,RemoteObj,Command)
            %
            
            if isempty(RemoteObj)
                % do nothing
                % Return NaNs
                [varargout{1:nargout}] = deal(NaN);
            else
            
                if isa(RemoteObj,'obs.remoteClass')
                    % NEED TO WRITE THIS PART
                    [varargout{1:nargout}] = obs.classCommand(RemoteObj,Command);
                else
                    %

                    [varargout{1:nargout}] = RemoteObj.(Command);

                end
            end

        end
    end
    
    
    % display/save
    methods
        function ImageToDisplay=divideByFlat(CameraObj,Image)
            % Subtract dark and divide image by flat
            % Input  : - An obs.camera object
            %          - An image. If not given then will use
            %            CameraObj.LastImage.
            % Output : - Dark subtracted and flat divided image
            
            if nargin<2
                Image = CameraObj.LastImage;
            end

            % convert to single
            ImageToDisplay = single(Image);
            
            OrigDir = pwd;
            
            % need to clean this part:
%             cd /media/last/data2/ServiceImages
%             cd /last02/data/serviceImages
            Dark = FITS.read2sim(fullfile(CameraObj.ConfigStruct.DarkDBDir, 'Dark.fits'));
%            S = load(fullfile(CameraObj.ConfigStruct.FlatDBDir,'Flat.mat'));  % need to update the image
%             cd(OrigDir);
%             Flat = S.Flat;
%             Flat.Im = Flat.Im./nanmedian(Flat.Im,'all');
            Flat = FITS.read2sim(fullfile(CameraObj.ConfigStruct.FlatDBDir,'Flat.fits'));  % need to update the image
            ImageToDisplay = ImageToDisplay(:,1:6387);
            Flat.Im        = Flat.Im(:,1:6387);

            ImageToDisplay = (ImageToDisplay - Dark.Im)./Flat.Im;
            
        end
        
        function displayImage(CameraObj,Display,DisplayZoom,DivideByFlat)
            % display LastImage in ds9 or matlab figure
            % Input : - A obs.camera object
            %         - Display window: 'ds9' | 'matlab' | ''.
            %           If empty then do not display the image.
            %           Default is to use the CameraObj.Display property.
            %         - Display Zoom for 'ds9'.
            %           Default is to use the CameraObj.DisplayZoom property.
            %         - A logical flag indicating if to subtract dark and
            %           divide by flat propr to display.
            %           Default is to use the CameraObj.DivideByFlat property.
            
            
            if nargin<4
                DivideByFlat = CameraObj.DivideByFlat;
                if nargin<3
                    DisplayZoom = CameraObj.DisplayZoom;
                    if nargin<2
                        Display = CameraObj.Display;
                    end
                end
            end
            
            % check if there is an image to display
            if ~isempty(CameraObj.LastImage)
                if ~isempty(Display)
                    if DivideByFlat
                        Image = CameraObj.divideByFlat(CameraObj.LastImage);
                    else
                        Image = CameraObj.LastImage;
                    end
                    % dispaly
                    switch lower(Display)
                        case 'ds9'
                            % Display in ds9 each camera in a different frame
                            if isempty(CameraObj.Frame)
                                Frame = CameraObj.CameraNumSDK;
                            else
                                Frame = CameraObj.Frame;
                            end
                            ds9(Image, 'frame', Frame);

                            if ~isempty(DisplayZoom)
                                ds9.zoom(DisplayZoom, DisplayZoom);
                            end
                            

                        case {'mat','matlab'}
                            % find resnoable range
                            Range = quantile(Image(:),[0.2, 0.95]);
                            imtool(Image,Range);
          
                        case ''
                            % no display
                            
                        otherwise
                            error('Unknown Display option');
                    end
                end
                        
            else
                if CameraObj.Verbose
                    fprintf('No Image to display\n');
                end
                CameraObj.LogFile.writeLog('No Image to display');
            end
            
        end
        
        
        function saveCurImage(CameraObj)
            % Save last image to disk according the user's settings
            % Also set LastImageSaved to true, until a new image is arrive
            
            
            % Construct directory name to save image in
            ProjName = sprintf('%s.%d.%02d.%d',CameraObj.ConfigStruct.ProjectName,...
                                               CameraObj.ConfigStruct.NodeNumber,...
                                               CameraObj.ConfigStruct.MountNumber,...
                                               CameraObj.ConfigStruct.CameraNumber);
            JD        = CameraObj.Handle.TimeStartLastImage + 1721058.5;   
            
            [FileName,Path]=imUtil.util.file.construct_filename('ProjName',ProjName,...
                                                                'Date',JD,...
                                                                'Filter',CameraObj.ConfigStruct.Filter,...
                                                                'FieldID',CameraObj.Object,...
                                                                'Type',CameraObj.ImType,...
                                                                'Level','raw',...
                                                                'SubLevel','',...
                                                                'Product','im',...
                                                                'Version',1,...
                                                                'FileType','fits',...
                                                                'DataDir',CameraObj.ConfigStruct.DataDir,...
                                                                'Base',CameraObj.ConfigStruct.BaseDir);
            CameraObj.LastImageName = FileName;
            
            %DirName = obs.util.config.constructDirName('raw');
            %PWD = pwd;
            
            %cd(DirName);
            
            [HeaderCell,Info]=constructHeader(CameraObj);  % get header
            
            % This part need to be cleaned
            %ConfigNode  = obs.util.config.read_config_file('/home/last/config/config.node.txt');
            %ConfigMount = obs.util.config.read_config_file('/home/last/config/config.mount.txt');

            % Construct image name   
%             if isempty(CameraObj.ConfigMount)
%                 NodeNumber  = 0;
%                 MountNumber = 0;
%                 CameraObj.LogFile.writeLog('ConfigMount is empty while saveCurImage');
%             else
%                 if Util.struct.isfield_notempty(CameraObj.ConfigMount,'NodeNumber')
%                     NodeNumber  = CameraObj.ConfigMount.NodeNumber;
%                 else
%                     NodeNumber  = 0;
%                 end
%                 if Util.struct.isfield_notempty(CameraObj.ConfigMount,'MountNumber')
%                     MountNumber = CameraObj.ConfigMount.MountNumber;
%                 else
%                     MountNumber = 0;
%                 end
%             end
            
            
            %ProjectName      = sprintf('LAST.%d.%02d.%d',NodeNumber,MountNumber,CameraObj.CameraNumber);
            %ImageDate        = datestr(CameraObj.Handle.TimeStartLastImage,'yyyymmdd.HHMMSS.FFF');
            %ObservatoryNode  = num2str(ConfigNode.ObservatoryNode);
            %MountGeoName     = num2str(ConfigMount.MountGeoName);

%             FieldID          = CameraObj.Object;
%             ImLevel          = 'raw';
%             ImSubLevel       = 'n';
%             ImProduct        = 'im';
%             ImVersion        = '1';
% 
%             % Image name legend:    LAST.Node.mount.camera_YYYYMMDD.HHMMSS.FFF_Filter_CCDnum_ImType.fits
%             % Image name example:   LAST.1.1.e_20200603.063549.030_clear_0_science.fits
%             %CameraObj.LastImageName = obs.util.config.constructImageName(ProjectName, ObservatoryNode, MountNumber, CameraObj.CameraNumber, ImageDate, CameraObj.Filter, FieldID, CameraObj.ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, CameraObj.ImageFormat);
%             CameraObj.LastImageName = obs.util.config.constructImageName(CameraObj.ConfigStruct.ProjectName,...
%                                                                          CameraObj.ConfigStruct.NodeNumber,...
%                                                                          CameraObj.ConfigStruct.MountNumber,...
%                                                                          CameraObj.CameraNumber,...
%                                                                          ImageDate, CameraObj.Filter, FieldID, CameraObj.ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, CameraObj.ImageFormat);
%             

            % Construct header
            % OLD: Header = CameraObj.updateHeader;
            
            if CameraObj.Verbose
                fprintf('Writing image name %s to disk\n',CameraObj.LastImageName);
            end

            % Write fits
            PWD = pwd;
            Util.OS.cdmkdir(Path);  % cd and on the fly mkdir
            FITS.write(single(CameraObj.Handle.LastImage), CameraObj.LastImageName,'Header',HeaderCell,'DataType','single');
            cd(PWD);
            
            
            CameraObj.LogFile.writeLog(sprintf('Image: %s is written', CameraObj.LastImageName))

            
            CameraObj.LastImageSaved = true;
            
        end
        
        function [HeaderCell,Info]=constructHeader(CameraObj)
            % Construct image header for Camera object
            % Output  : - A 3 column cell array with header for image
            %           - A structure with all the header key and vals.

            
            RAD = 180./pi;
            
            % Image related information
            %    12345678
            Info.NAXIS    = ndims(CameraObj.LastImage);
            SizeImIJ      = size(CameraObj.LastImage);
            Info.NAXIS1   = SizeImIJ(2);
            Info.NAXIS2   = SizeImIJ(1);
            Info.BITPIX   = -32;
            Info.BZERO    = 0.0;
            Info.BSCALE   = 1.0;
            Info.IMTYPE   = CameraObj.ImType;
            Info.OBJECT   = CameraObj.Object;            
            % Gain
            Key   = 'GAIN';
            Field = Key;
            if isfield(CameraObj.ConfigStruct,Field)
                Info.(Key)     = CameraObj.ConfigStruct.(Field);
            else
                Info.(Key)     = NaN;
            end
            
            % internal gain
            Info.INTGAIN  = CameraObj.Gain;
            
            % Read noise
            Key   = 'READNOI';
            Field = Key;
            if isfield(CameraObj.ConfigStruct,Field)
                Info.(Key)     = CameraObj.ConfigStruct.(Field);
            else
                Info.(Key)     = NaN;
            end
            
            % Dark current
            Key   = 'DARKCUR';
            Field = Key;
            if isfield(CameraObj.ConfigStruct,Field)
                Info.(Key)     = CameraObj.ConfigStruct.(Field);
            else
                Info.(Key)     = NaN;
            end
            %
            Info.BINX     = CameraObj.Binning(1);
            Info.BINY     = CameraObj.Binning(2);
            % 
            Info.CamNum   = CameraObj.CameraNumber;
            Info.CamPos   = CameraObj.CameraPos;
            Info.CamType  = CameraObj.CameraType;
            Info.CamModel = CameraObj.CameraModel;
            Info.CamName  = CameraObj.CameraName;
            % Mount informtaion
            if Util.struct.isfield_notempty(CameraObj.ConfigMount,'MountNumber')
                Info.MountNum = CameraObj.ConfigMount.MountNumber;
            else
                Info.MountNum = NaN;
            end
            
            % OBSERVER
            %ORIGIN
            %OBSNAME
            %OBSPLACE
            
            
            if Util.struct.isfield_notempty(CameraObj.ConfigMount,'ObsLon')
                Info.ObsLon = CameraObj.ConfigMount.ObsLon;
            else
                Info.ObsLon = NaN;
            end
            if Util.struct.isfield_notempty(CameraObj.ConfigMount,'ObsLat')
                Info.ObsLat = CameraObj.ConfigMount.ObsLat;
            else
                Info.ObsLat = NaN;
            end
            if Util.struct.isfield_notempty(CameraObj.ConfigMount,'ObsHeight')
                Info.ObsHeight = CameraObj.ConfigMount.ObsHeight;
            else
                Info.ObsHeight = NaN;
            end
            
            %Info.JD       = juliandate(CameraObj.Handle.LastImageTime);
            Info.JD       = 1721058.5 + CameraObj.Handle.TimeStartLastImage;
            %Info.ExpTime  = CameraObj.Handle.LastImageExpTime;
            Info.ExpTime  = CameraObj.ExpTime;
            Info.LST      = celestial.time.lst(Info.JD,Info.ObsLon./RAD,'a').*360;  % deg
            DateObs       = convert.time(Info.JD,'JD','StrDate');
            Info.DATE_OBS = DateObs{1};
            
            
            % get RA/Dec - Mount equinox of date
            Info.M_RA     = commCommand(CameraObj, CameraObj.HandleMount,'RA');
            
            Info.M_DEC    = commCommand(CameraObj, CameraObj.HandleMount,'Dec');
            Info.M_HA     = convert.minusPi2Pi(Info.LST - Info.M_RA);
            % RA/Dec - mount J2000
            Info.M_JRA    = commCommand(CameraObj, CameraObj.HandleMount,'j2000_RA');
            Info.M_JDEC   = commCommand(CameraObj, CameraObj.HandleMount,'j2000_Dec');
            Info.M_HA     = convert.minusPi2Pi(Info.LST - Info.M_JRA);
            % RA/Dec - J2000 camera center
            if ~isempty(CameraObj.ConfigStruct)
                if Util.struct.isfield_notempty(CameraObj.ConfigStruct,'MountCameraDist') && ...
                        Util.struct.isfield_notempty(CameraObj.ConfigStruct,'MountCameraPA')
                    [Info.DEC, Info.RA] = reckon(Info.M_JDEC,...
                                             Info.M_JRA,...
                                             CameraObj.ConfigStruct.MountCameraDist,...
                                             CameraObj.ConfigStruct.MountCameraPA,'degrees');
                else
                    Info.RA  = Info.M_JDEC;
                    Info.DEC = Info.M_JRA;
                end
                Info.RA = mod(Info.RA,360);
            else
                Info.RA  = Info.M_JDEC;
                Info.DEC = Info.M_JRA;
            end
                
            
            
            Info.AZ       = commCommand(CameraObj, CameraObj.HandleMount,'Az');
            Info.ALT      = commCommand(CameraObj, CameraObj.HandleMount,'Alt');
            Info.EQUINOX  = 2000.0;
            Info.AIRMASS  = celestial.coo.hardie(pi./2-Info.ALT./RAD);
            Info.TRK_RA   = commCommand(CameraObj, CameraObj.HandleMount,'trackingSpeedRA')./3600;  % [arcsec/s]
            Info.TRK_DEC  = commCommand(CameraObj, CameraObj.HandleMount,'trackingSpeedDec')./3600;  % [arcsec/s]
            
            % focuser information
            Info.FOCUS    = commCommand(CameraObj, CameraObj.HandleFocuser,'Pos');
            Info.PRVFOCUS = commCommand(CameraObj, CameraObj.HandleFocuser,'LastPos');
            
         
            
            % struct to HeaderCell + comments
            % Input : Info, CommentsDB
            CommentsDB = CameraObj.ConfigHeader;
           
            FN  = fieldnames(Info);
            Nfn = numel(FN);
            if ~isempty(CommentsDB)
                CommentFN = fieldnames(CommentsDB);
            end
            HeaderCell = cell(Nfn,3);
            for Ifn=1:1:Nfn
                HeaderCell{Ifn,1} = upper(FN{Ifn});
                HeaderCell{Ifn,2} = Info.(FN{Ifn});
                if ~isempty(CommentsDB)
                    % get comment
                    Ind = find(strcmpi(FN{Ifn},CommentFN));
                    if ~isempty(Ind)
                        HeaderCell{Ifn,3} = CommentsDB.(CommentFN{Ind});
                    end
                end
            end
            
        end
        
        
       
        function Header=updateHeader(CameraObj)
            % obsolote
            
            RAD = 180./pi;
            DateObs = datestr(CameraObj.TimeStart,'yyyy-mm-ddTHHMMSS.FFF');
            DateVec = datevec(CameraObj.TimeStart);
            JD      = celestial.time.julday(DateVec(:,[3 2 1 4 5 6]));

            if (isempty(CameraObj.HandleMount))
                MountGeoName = 0;
                RA  = NaN;
                Dec = NaN;
                HA  = NaN;
                LST = NaN;
                Az  = NaN;
                Alt = NaN;
                TrackingSpeed = NaN;
                IsCounterWeightDown = NaN;
            else
                MountGeoName = CameraObj.HandleMount.MountNumber;
                RA  = CameraObj.HandleMount.RA;
                Dec = CameraObj.HandleMount.Dec;
                HA  = CameraObj.HandleMount.HA;
                LST = celestial.time.lst(JD,CameraObj.HandleMount.ObsLon./RAD,'a').*360;
                Az  = CameraObj.HandleMount.Az;
                Alt = CameraObj.HandleMount.Alt;
                TrackingSpeed = CameraObj.HandleMount.TrackingSpeed;
                IsCounterWeightDown = NaN; %CameraObj.HandleMount.IsCounterWeightDown;
            end

            if (isempty(CameraObj.HandleFocuser))
                FocPos = NaN;
                FocPrevPos = NaN;
            else
                FocPos = CameraObj.HandleFocuser.Pos;
                FocPrevPos = CameraObj.HandleFocuser.LastPos;
            end

            ConfigNode=obs.util.config.read_config_file('/home/last/config/config.node.txt');
            ObservatoryNode = ConfigNode.ObservatoryNode;

            % Old config file reading (before Dec 2020):
            %   Instrument = sprintf('LAST.%s.%s.%s', obs.util.config.readSystemConfigFile('ObservatoryNode'), MountGeoName, CameraObj.CamGeoName); % 'LAST.node.mount.camera'
            % New config file reading (after Dec 2020):
            Instrument = sprintf('LAST.%s.%s.%s', ObservatoryNode, MountGeoName, CameraObj.CameraGeoName); % 'LAST.node.mount.camera'
            Header   = {'NAXIS',2,'number of axes';...
                        'NAXIS1',size(CameraObj.LastImage,2),'size of axis 1 (X)';...
                        'NAXIS2',size(CameraObj.LastImage,1),'size of axis 2 (Y)';...
                        'BITPIX',-32,'bits per data value';...
                        'BZERO',0.0,'zero point in scaling equation';...
                        'BSCALE',1.0,'linear factor in scaling equation';...
                        'BUNIT','ADU','physical units of the array values';...
                        'IMTYPE',CameraObj.ImType,'Image type: dark/flat/focus/science/test';...
                        'INTGAIN',CameraObj.Gain,'Camera internal gain level';...
                        'INTOFFS',CameraObj.Handle.Offset,'Camera internal offset level';...
                        'BINX',CameraObj.Binning(1),'Camera binning in X-axis';...
                        'BINY',CameraObj.Binning(2),'Camera binning in Y-axis';...
                        'ORIGIN','Weizmann Institute of Science','organization responsible for the data';...
                        'TELESCOP','Celestron RASA 11','name of telescope';...
                        'CAMERA',[CameraObj.CameraType, ' ', CameraObj.CameraModel],'Camera name';...
                        'INSTRUME',Instrument,'LAST.node.mount.camera';...
                        'OBSERVER','LAST','observer who acquired the data';...
                        'REFERENC','NAN','bibliographic reference';...
                        'EXPTIME',CameraObj.ExpTime,'Exposure time (s)';...
                        'TEMP_DET',CameraObj.Temperature,'Detector temperature';...
                        'COOLERPWR',CameraObj.CoolingPower,'Percentage of the cooling power';...
                        'RA',RA,'J2000.0 R.A. [deg]';...
                        'DEC',Dec,'J2000.0 Dec. [deg]';...
                        'HA',HA,'Hour Angle [deg]';...
                        'LST',LST,'LST [deg]';...
                        'AZ',Az,'Azimuth';...
                        'ALT',Alt,'Altitude';...
                        'EQUINOX',2000.0,'Coordinates equinox (Julian years)';...
                        'TRACKSP',TrackingSpeed,'';...
                        'CWDOWN',IsCounterWeightDown,'Is Counter Weight Down flag';...
                        'FOCUS',FocPos,'Focus value';...
                        'PRFOCUS',FocPrevPos,'Previous Focus value';...
                        'CDELT1',0.000347,'coordinate increment along axis 1 (deg/pix)';...
                        'CDELT2',0.000347,'coordinate increment along axis 2 (deg/pix)';...
                        'SCALE',1.251,'Pixel scale (arcsec/pix)';...
                        'DATE-OBS',DateObs,'date of the observation';...
                        'JD',JD,'Julian day';...
                        'MJD',JD-2400000.5,'Modified Julian day';...
                        'OBJECT',CameraObj.Object,'Object/field name'};
        end


    end
    
    
    
end