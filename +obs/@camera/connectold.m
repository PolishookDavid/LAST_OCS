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
