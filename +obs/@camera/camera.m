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
        CameraType char        = 'QHY';
        CameraModel char       = 'QHY600M-PH';
        CameraName char        = '';
        CameraNumSDK double                         % Camera number in the SDK
        CameraNumber double                         %  1       2      3      4
        CameraPos char         = '';                % 'NE' | 'SE' | 'SW' | 'NW'
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
        
    end
    
    % display
    properties(Hidden)
        Display              = 'ds9';   % 'ds9' | 'matlab' | ''
        DisplayZoom double   = 0.08;    % ds9 zoom
        DivideByFlat logical = true;    % subtract dark and divide by flat before dispaly
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
        
        
        function CameraObj=camera(CameraType)
            % Camera object constructor
            % This function does not populate the Handle property
            % This is done in the connect stage
            % Input  : - CameraType: 'QHY' | 'ZWO'
            % Example: C=obs.camera('qhy')
            
            DefaultCameraType    = 'QHY';
            
    
            if nargin<1
                CameraType = DefaultCameraType;
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
            
            
        end
       
    
    end
    
    % static methods
    methods (Static)
        function CameraNumSDK=identify_all_cameras(CameraName,HandleDriver)
            % Identify all QHY cameras connected to the computer
            % Input  : - CameraName (e.g.., 'QHY367C-e2f51243929ddaaf5').
            %          - Handle driver. If empty, then will created
            % Output : - Camera number as identified by the SDK
            % Tested : with QHY/SDK 21-2-1 
            %  https://www.qhyccd.com/file/repository/publish/SDK/210201/sdk_linux64_21.02.01.tgz
            % Example: CameraNumSDK=obs.camera.identify_all_cameras(CameraName,HandleDriver)
            
            if nargin<2
                HandleDriver = [];
            end
            
            if isempty(HandleDriver)
                Q       = inst.QHYccd;          % create one camera object and DO NOT connect yet
            end
            Q.verbose   = false;                % optional if you want to see less blabber
            AllCamNames = Q.allQHYCameraNames;

            %CameraNumSDK = find(strcmp(AllCamNames,'QHY367C-e2f51243929ddaaf5'));
            CameraNumSDK = find(strcmp(AllCamNames,CameraName));
        end
       
        
    end

    
    % Aux
%     methods
%         
%         
%         function [ConfigStruct,ConfigLogical,ConfigPhysical,ConfigFileNameLogical,ConfigFileNamePhysical]=readConfig(Obj,Address,ConfigBaseName,PhysicalKeyName)
%             % read configuration (logical and physical) file into
%             % ConfigStruct.
%             % Description: Read the logical configuration file, the
%             %              physical configuration file and the mount onfig file, and:
%             %              store it in ConfigStruct
%             %              To update the properties in the object according
%             %              to properties in the Config file use:
%             %              updatePropFromConfig
%             %              Mount config will be read into M.ConfigMount
%             % Input  : - Mount object
%             %          - This can be:
%             %            1. A mount address which is a vector of
%             %               [NodeNumber, MountNumber]
%             %            2. A mount configuration file name (string).
%             %            3. Empty [default]. In this case, some default
%             %               values will be used.
%             %          - ConfigBaseName. Default is 'config.camera'.
%             %          - Keyword in the logical configuration under which
%             %            the physical device name reside.
%             %            If this is not provided than will not read the
%             %            physical device config.
%             % Output : - Merged Structure of logical and physical config.
%             %          - Structure of the logical configuration 
%             %          - Structure of the physical configuration 
%             %          - Logical config file name
%             %          - Physical config file name
%             
%             if nargin<4
%                 PhysicalKeyName = [];
%                 if nargin<3
%                     ConfigBaseName = 'config.camera';
%                     if nargin<2
%                         Address = [];
%                     end
%                 end
%             end
%             % read the configuratin file
%             if ischar(Address)
%                 ConfigFileNameLogical = Address;
%             else
%                 switch numel(Address)
%                     case 1
%                         ConfigFileNameLogical = sprintf('%s_%d.txt',ConfigBaseName,Address);
%                     case 2
%                         ConfigFileNameLogical = sprintf('%s_%d_%d.txt',ConfigBaseName,Address);
%                     case 3
%                         ConfigFileNameLogical = sprintf('%s_%d_%d_%d.txt',ConfigBaseName,Address);
%                     otherwise
%                         % no config file
%                         ConfigFileNameLogical = [];
%                 end
%             end
%             Obj.Config = ConfigFileNameLogical;
%             
%             ConfigLogical  = [];
%             ConfigPhysical = [];
%             ConfigFileNamePhysical = [];
%             if ~isempty(Obj.Config)
%                 
%                 ConfigLogical = Obj.loadConfiguration(Obj.Config, false);
%                 
%                 if ~isempty(PhysicalKeyName)
%                     % read the physical name - e.g., CameraName
%                     PhysicalName           = ConfigLogical.(PhysicalKeyName);
%                     ConfigFileNamePhysical = sprintf('config.%s.txt',PhysicalName);
%                     ConfigPhysical         = Obj.loadConfiguration(ConfigFileNamePhysical, false);
%                     
%                     % merge with ConfigLogical
%                     ConfigStruct = Util.struct.mergeStruct(ConfigLogical,ConfigPhysical);
%                 else
%                     ConfigStruct = ConfigLogical;
%                 end
%                 
%                 Obj.ConfigStruct = ConfigStruct;
%                 
%                 % read mount config
%                 ConfigMountFileName = sprintf('config.mount_%d_%d.txt',Address(1:2));
%                 Obj.ConfigMount = Obj.loadConfiguration(ConfigMountFileName, false);
%                 
%             end
%             
%             
%             
%             
%         end
%             
%         function Obj=updatePropFromConfig(Obj,ListProp,ConfigStruct)
%             % Update the properties in the Object according to their
%             % value in ConfigStruct.
%             % Input  : - An object (e.g., obs.camera object).
%             %          - A cell array of properties to copy from the
%             %            ConfigStruct to the object.
%             %            E.g.,
%             %            {'CameraType','CameraName','CameraModel'}
%             %          - ConfigStruct: A structure containing the
%             %            Config file content. If not provided, then will
%             %            be taken from the Obj.ConfigStruct.
%             if nargin<3
%                 ConfigStruct = Obj.ConfigStruct;
%             end
% 
%             Nprop = numel(ListProp);
%             for Iprop=1:1:Nprop
%                 if isfield(ConfigStruct,ListProp{Iprop})
%                     Obj.(ListProp{Iprop}) = ConfigStruct.(ListProp{Iprop});
%                 else
%                     Obj.LogFile.writeLog(sprintf('Error: Propery %s was not found in ConfigStruct',ListProp{Iprop}));
%                 end
%             end
%         end
%                 
%         
%     end
    
    % connect
    methods 
        function CameraObj=connect(CameraObj,CameraAddress,varargin)    
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
                        CameraNumSDK = obs.camera.identify_all_cameras(CameraName);
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
                        MsgObj     = obs.remoteClass(RemoteName,DestinationIP,DestinationPort,LocalPort);
                        MsgObj.Messenger.connect;
                        CameraObj.HandleMount = MsgObj;
                        
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
           
           if CameraObj.IsConnected
              
              % Call disconnect using the camera handle object
              Success = CameraObj.Handle.disconnect;
              CameraObj.IsConnected = ~Success;
              
              CameraObj.LogFile.writeLog(sprintf('Disconnect CameraName: %s',CameraObj.CameraName));
           end
        end

        function delete(CameraObj)
            % Delete properly driver object + set IsConnected to false
            
            CameraObj.Handle.delete;
            CameraObj.IsConnected = false;
        end

        % abort 
        % for abort use: CameraObj.Handle.abort
        
    end
            
    % getters/setters
    methods
        % ExpTime
        function Output=get.ExpTime(Obj)
            % getter template
            if Obj.IsConnected 
                Output = Obj.Handle.ExpTime;
            else
                ErrorStr = 'Can not get ExpTime because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        function set.ExpTime(Obj,InputPar)
            % setter template
            if Obj.IsConnected 
                if InputPar>Obj.MaxExpTime
                    Obj.LogFile.writeLog(sprintf('Error: Requested ExpTime is above MaxExpTime of %f s',Obj.MaxExpTime));
                    error('Requested ExpTime is above MaxExpTime of %f s',Obj.MaxExpTime);
                end
                Obj.Handle.ExpTime = InputPar;
            else
                ErrorStr = 'Can not set ExpTime because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % Temperature
        function Output=get.Temperature(Obj)
            % getter template
            if Obj.IsConnected 
                Output = Obj.Handle.Temperature;
            else
                ErrorStr = 'Can not get Tempearture because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
                
            end
        end
        
        function set.Temperature(Obj,InputPar)
            % setter template
            if Obj.IsConnected 
                Obj.Handle.Temperature = InputPar;
            else
                ErrorStr = 'Can not set Tempearture because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
                
            end
        end
        
        % Status
        function Output=get.Status(Obj)
            % getter template
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
            if Obj.IsConnected 
                Output = Obj.Handle.CoolingPower;
            else
                ErrorStr = 'Can not get CoolingPower because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % TimeStart
        function Output=get.TimeStart(Obj)
            % getter template
            if Obj.IsConnected 
                Output = Obj.Handle.TimeStart;
            else
                ErrorStr = 'Can not get TimeStart because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % TimeEnd
        function Output=get.TimeEnd(Obj)
            % getter template
            if Obj.IsConnected 
                Output = Obj.Handle.TimeEnd;
            else
                ErrorStr = 'Can not get TimeEnd because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % LastError
        function Output=get.LastError(Obj)
            % getter template
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
            if Obj.IsConnected 
                Output = Obj.Handle.ReadMode;
            else
                ErrorStr = 'Can not get ReadMode because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        function set.ReadMode(Obj,InputPar)
            % setter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            if Obj.IsConnected 
                Obj.Handle.ReadMode = InputPar;
            else
                ErrorStr = 'Can not set ReadMode because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % Offset
        function Output=get.Offset(Obj)
            % getter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            if Obj.IsConnected 
                Output = Obj.Handle.Offset;
            else
                ErrorStr = 'Can not get Offset because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        function set.Offset(Obj,InputPar)
            % setter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            if Obj.IsConnected 
                Obj.Handle.Offset = InputPar;
            else
                ErrorStr = 'Can not set Offset because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % Gain
        function Output=get.Gain(Obj)
            % getter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            if Obj.IsConnected 
                Output = Obj.Handle.Gain;
            else
                ErrorStr = 'Can not get Gain because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        function set.Gain(Obj,InputPar)
            % setter template
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            if Obj.IsConnected 
                Obj.Handle.Gain = InputPar;
            else
                ErrorStr = 'Can not set Gain because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % Binning
        function Output=get.Binning(Obj)
            % getter template
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
            if Obj.IsConnected 
                Obj.Handle.Binning = InputPar;
            else
                ErrorStr = 'Can not set Binning because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % CoolingStatus
        function Output=get.CoolingStatus(Obj)
            % getter template
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
            if Obj.IsConnected 
                Obj.Handle.CoolingStatus = InputPar;
            else
                ErrorStr = 'Can not set CoolingPower because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        
    end
    
    % callback, timers, wiats
    methods
        function callbackSaveAndDisplay(CameraObj, ~, ~)
            % A callback function: if the camera is idle than stop time,
            % save and display image
            % Input  : - Camera object.
            
            % This function may work in two manners:
            % 1. Check for idle status - however, this is problematic when
            % taking sequence of imaes.
            % 2. wait for LastImage to be non empty and LastImageSaved to
            % be false.
            Method = 1;
            
            %CameraObj.Status
            switch Method
                case 1

                    switch lower(CameraObj.Status)
                        case 'idle'
                            % camera is ready
                            % Stop timer
                            stop(CameraObj.ReadoutTimer);


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
                    
                case 2
                    if ~isempty(CameraObj.LastImage) && ~CameraObj.LastImageSaved
                        % new image that was not saved is present in buffer
                        % Stop timer
                        stop(CameraObj.ReadoutTimer);


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

                otherwise
                    error('Unknown Method option');
            end

        end
        
        function Flag = waitFinish(CameraObj)
            % wait until the camera ended exposing, readout, and writing image and returned to idle mode

            WaitTime = 0.01;
            Flag = false;
            
            if CameraObj.Verbose
                fprintf('Wait for idle camera\n');
            end
            
            StopWaiting = false;
            while ~StopWaiting
                
                pause(WaitTime);
                Status = CameraObj.Status;
                switch lower(Status)
                    case {'exposing','reading'}
                        % do nothing - continue waiting
                        
                    case 'idle'
                        StopWaiting = true;
                        Flag = true;
                        
                    otherwise
                        StopWaiting = true;
                        if CameraObj.Verbose
                            warning('waitFinish encounter an illegal camera status: %s',Status);
                        end
                        CameraObj.LogFile.writeLog(sprintf('waitFinish encounter an illegal camera status: %s',Status));
                end
            end
                        
        end


        
    end
        


    
    % basic functions
    % takeExposure
    methods
        function Flag=takeExposure(CameraObj,ExpTime,Nimages,WaitFinish)
            % Take a single or multiple number of exposures
            % Package: +obs.@mount
            % Input  : - A camera object.
            %          - Exposure time [s]. If provided this will override
            %            the CameraObj.ExpTime, and the CameraObj.ExpTime
            %            will be set to this value.
            %          - Number of images to obtain. Default is 1.
            %          - waitFinish flag: if true than will act as a
            %            blocking function and return the prompt after the
            %            last image is downloaded.
            %            if false, will return thre prompt, after the last
            %            image has started.
            %            Default is false.
            % Output : - Sucess flag.

            MinExpTimeForSave = 4;  % [s] Minimum ExpTime below SaveDuringNextExp is disabled
            
            if nargin<4
                WaitFinish = false;
                if nargin<3
                    Nimages = 1;
                    if nargin<2
                        ExpTime = CameraObj.ExpTime;
                    end
                end
            end
            %ExpTime = CameraObj.ExpTime;
            
            Flag = false;
            if CameraObj.IsConnected
                Status = CameraObj.Status;
                %SaveDuringNextExp = CameraObj.SaveDuringNextExp;
                switch lower(CameraObj.Status)
                    case 'idle'
                        % take Nimages Exposures
                        for Iimage=1:1:Nimages
                            % Execute exposure command
                            CameraObj.Handle.takeExposure(ExpTime);
                            
                            if CameraObj.Verbose
                                fprintf('Start Exposure %d of %d: ExpTime=%.3f s\n',Iimage,Nimages,ExpTime);
                            end
                            CameraObj.LogFile.writeLog(sprintf('Start Exposure %d of %d: ExpTime=%.3f s',Iimage,Nimages,ExpTime));
                            
                            % save
                            % There are three modes:
                            % 1. Do nothing - save the image while the next
                            % exposure is takem.
                            % 2. Save the previously taken image
                            % 3. Save the image immidetily after it is
                            % taken (when camera is idle).
                            
                            
%                             if AbortSequence
%                                 SaveMode = 3;
%                             else
%                                 if SaveDuringNextExp && ExpTime>MinExpTimeForSave
%                                     if Iimage==1 
%                                         if Nimages>1
%                                             % first out of sequence
%                                             SaveMode = 1;
%                                         else
%                                             % first out of one
%                                             SaveMode = 3;
%                                         end
%                                     else
%                                         if Iimage==Nimage
%                                             % The last image out of many
%                                             SaveMode = 3;
%                                         else
%                                             % not the first and not the last
%                                             SaveMode = 2;
%                                         end
%                                     end
%                                 else
%                                     SaveMode = 3;
%                                 end
%                             end

                            SaveMode = 3;
                                
                            switch SaveMode
                                case 1
                                    % save the image while the next image
                                    % is taken
                                    % assume the image will be store in
                                    % LastImage
                                    CameraObj.waitFinish;
                                case 2
                                    % save the previous image
                                    if (CameraObj.SaveOnDisk)
                                        CameraObj.saveCurImage;
                                    end
                                    CameraObj.waitFinish
                                case 3
                                    % start a callback timer that will save
                                    % the image immidetly after it is taken
                                    
                                    % start timer
                                    CameraObj.ReadoutTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate',...
                                                                   'Name', 'camera-timer',...
                                                                   'Period', 0.2, 'StartDelay', max(0,ExpTime-1),...
                                                                   'TimerFcn', @CameraObj.callbackSaveAndDisplay,...
                                                                   'ErrorFcn', 'beep');
                                    start(CameraObj.ReadoutTimer);
                                    %CameraObj.LogFile.writeLog('Start image readout timer')
                                    
                                    if WaitFinish
                                        % blocking
                                        CameraObj.waitFinish;
                                    end
                                otherwise
                                    error('Unknown SaveMode option');
                            end
                            
                        end  % end for loop
                        Flag = true;
           
                    otherwise
                        if CameraObj.Verbose
                            fprintf('Can not take Exposure because camera is %s instead of idle\n',Status);
                        end
                        CameraObj.LogFile.writeLog(sprintf('Can not take Exposure because camera is %s instead of idle\n',Status));
                end
            else
                if CameraObj.Verbose
                    fprintf('Can not take Exposure because camera is not connected\n');
                end
                CameraObj.LogFile.writeLog(sprintf('Can not take Exposure because camera is not connected\n'));
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
            cd /media/last/data2/ServiceImages
            Dark = FITS.read2sim('Dark.fits');
            S = load('Flat.mat');  % need to update the image
            cd(OrigDir);
            Flat = S.Flat;
            Flat.Im = Flat.Im./nanmedian(Flat.Im,'all');

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
                            ds9(Image, 'frame', CameraObj.CameraNumSDK)

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
            DirName = obs.util.config.constructDirName('raw');
            PWD = pwd;
            
            cd(DirName);
            
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
            ImageDate        = datestr(CameraObj.TimeStart,'yyyymmdd.HHMMSS.FFF');
            %ObservatoryNode  = num2str(ConfigNode.ObservatoryNode);
            %MountGeoName     = num2str(ConfigMount.MountGeoName);

            FieldID          = CameraObj.Object;
            ImLevel          = 'raw';
            ImSubLevel       = 'n';
            ImProduct        = 'im';
            ImVersion        = '1';

            % Image name legend:    LAST.Node.mount.camera_YYYYMMDD.HHMMSS.FFF_Filter_CCDnum_ImType.fits
            % Image name example:   LAST.1.1.e_20200603.063549.030_clear_0_science.fits
            %CameraObj.LastImageName = obs.util.config.constructImageName(ProjectName, ObservatoryNode, MountNumber, CameraObj.CameraNumber, ImageDate, CameraObj.Filter, FieldID, CameraObj.ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, CameraObj.ImageFormat);
            CameraObj.LastImageName = obs.util.config.constructImageName(CameraObj.ConfigStruct.ProjectName,...
                                                                         CameraObj.ConfigStruct.NodeNumber,...
                                                                         CameraObj.ConfigStruct.MountNumber,...
                                                                         CameraObj.CameraNumber,...
                                                                         ImageDate, CameraObj.Filter, FieldID, CameraObj.ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, CameraObj.ImageFormat);
            

            % Construct header
            % OLD: Header = CameraObj.updateHeader;

            % Write fits
            FITS.write(single(CameraObj.Handle.LastImage), CameraObj.LastImageName,'Header',HeaderCell,'DataType','single');

            CameraObj.LogFile.writeLog(sprintf('Image: %s is written', CameraObj.LastImageName))

            cd(PWD);
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
            Info.JD       = 1721058.5 + CameraObj.TimeStart;
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