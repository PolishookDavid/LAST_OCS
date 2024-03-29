function success = connect(CameraObj, CameraNum, MountHn, FocusHn)
    % Open the connection with a specific camera.
    % Input  : - Camera object
    %          - Camera number (as enumerated by the SDK)
    %            or camera address [Node, Mount, CameraID].
    %            The camera address option works only with QHYccd.
    %          - Optional Mount object.
    %          - Optional Focus object
    % Output : - A succses flag
    % Example: C.connect([1 1 3])  % will read configuration file 1,1,3
    %          C.connect
    %          C.connect([1 1 3],M,F);  % supply the Mount and Focuser handles
    % By : Eran Ofek         Feb 2021
    
    
    % Identify specific camera to connect to
    % Identified using the CameraName input argument
    % Can be: 
    
    
    if nargin<4
        FocusHn = [];
        if nargin<3
            MountHn = [];
            if nargin<2
                CameraNum     = [];
                %CameraAddress = [];
            end
        end
    end
    CameraAddress = CameraNum;
    
    CameraObj.HandleMount   = MountHn;
    CameraObj.HandleFocuser = FocusHn;    
    
    
        
    if numel(CameraAddress)==3
        
        % Read Configuration file
        % This can
        %    Camera Observatory address : [Node Mount CameraID], where CameraID is sorted by [1=NE, 2=SE, 3=SW, 4=NW]
        LogicalConfigFileName  = sprintf('config.camera_%d_%d_%d.txt',CameraAddress);
        % Read logical configuration file
        Config.LogicalCamera   = loadConfiguration(CameraObj,LogicalConfigFileName,false);
        % Read physical camera configuration file
        PhysicalConfigFileName = sprintf('config.%s',Config.LogicalCamera.CameraName);
        Config.PhysicalCamera  = loadConfiguration(CameraObj,PhysicalConfigFileName,false);
        
        CameraObj.Config = LogicalConfigFileName;
        % ConfigStruct
        CameraObj.ConfigStruct.PhysicalCamera = Config.PhysicalCamera;
        CameraObj.ConfigStruct.LogicalCamera  = Config.LogicalCamera;
        
        CameraObj.CameraModel    = Config.PhysicalCamera.CameraModel;
        CameraObj.CameraGeoName  = Config.LogicalCamera.CameraNumber;
        
        % The following function search for all cameras (supported by the
        % SDK) that are connected to the computer
        CameraNum = 1;
        %Q = inst.QHYccd;
        %AllCamNames = Q.allQHYCameraNames;
        %%clear Q;
        %% The camera number as refered by the SDK
        %CameraNum = find(strcmp(AllCamNames,Config.PhysicalCamera.CameraName));
        %if isnan(CameraNum)
        %    error('Can not find camera %s on computer',Config.PhysicalCamera.CameraName);
        %end
        
    else
        
        if numel(CameraAddress)==1
            CameraNum = CameraAddress;
        else
            CameraNum = 1;  % The camera number as refered by the SDK
        end
        CameraAddress = [NaN NaN NaN];
    end
        
    success = false;
    
    if CameraObj.IsConnected
        fprintf('The camera is possibly already connected - do nothing');
    else
        % Connect to camera
        success = CameraObj.Handle.connect(CameraNum);
        CameraObj.IsConnected = success;
        if CameraObj.Verbose
            fprintf('>>>>> Connecting to camera <<<<<\n');
        end

        if success
            
            CameraObj.CameraNum   = CameraObj.Handle.CameraNum;
            
            
            % Open a log file
            CameraObj.LogFile = logFile;
            CameraObj.LogFile.logOwner = sprintf('Camera_%d_%d_%d',CameraAddress);
            CameraObj.LogFile.writeLog(sprintf('Connected to camera %s',CameraObj.Handle.CameraName)); %Config.PhysicalCamera.CamName);
            CameraObj.LogFile.closeFile;
            
        end
    end
    
        
if 1==0
    % Read configure files:
   % Old method to read config files... DP Feb 15, 2021
%     ConfigNode=obs.util.config.read_config_file('/home/last/config/config.node.txt');
%     ConfigMount=obs.util.config.read_config_file('/home/last/config/config.mount.txt');
     % NEED TO REPLACE THIS BY NEW CONFIG FILE BELOW
     ConfigCam=obs.util.config.read_config_file('/home/last/config/config.camera.txt');
    ConfigNode = configfile.read_config('config.node_1.txt');
    ConfigMount = configfile.read_config('config.mount_1_1.txt');
    
     % e.g., CameraObj.Config = 'config.camera_1_1_1.txt'
     Config = CameraObj.loadConfiguration(CameraObj.Config,false)
    
    
    % NEED TO OPERATE THIS INSTEAD OF OLD CONFIG FILE ABOVE
%    ConfigCam = configfile.read_config('config.camera_1_1_1.txt');

    % Patch! More than one connection to the camera make matlab stuck while
    % reading out the first image taken. Do NOT allow a second connection. 
    if ~CameraObj.IsConnected

        %    % Add this command to the crontab of the computer:
        %    % Update computer clock using the Network Time Protocol (NTP)
        %    if CameraObj.Verbose, fprintf('>>> Updating computer clock with the Network Time Protocol (NTP).\n Wait for a few seconds\n'); end
        %    CameraObj.LogFile.writeLog('Updating computer clock with the Network Time Protocol (NTP).')
        %    obs.util.update_time_NTP;

        if nargin==1
            CameraNum = 1;
            CameraObj.HandleMount   = [];
            CameraObj.HandleFocuser = [];
        elseif nargin==2
            CameraObj.HandleMount   = [];
            CameraObj.HandleFocuser = [];
        elseif nargin==3
            CameraObj.HandleMount   = MountHn;
            CameraObj.HandleFocuser = [];
        elseif nargin==4
            CameraObj.HandleMount   = MountHn;
            CameraObj.HandleFocuser = FocusHn;    
        else
            error('Illegal number of input arguments');
        end
        
        if (isempty(CameraObj.HandleMount))
           if CameraObj.Verbose, fprintf('>>>>> warning: Mount was not connected <<<<<\n'); end
        end
        if (isempty(CameraObj.HandleFocuser))
           if CameraObj.Verbose, fprintf('>>>>> warning: Focuser was not connected <<<<<\n'); end
        end

            
%%%%%%%% DP FEB 1        
        
%          REMOVE THIS OLDER SECTION - DP AUG 18, 2020 
        
        if nargin==1
           CameraNum = 1;
           
           CameraObj.HandleMount   = [];
           CameraObj.HandleFocuser = [];
           
           if CameraObj.Verbose
               fprintf('>>>>> warning: Mount and focuser were not connected <<<<<\n');
           end
        elseif nargin==2
            
           
           if CameraObj.Verbose
               fprintf('>>>>> warning: Mount and focuser were not connected <<<<<\n');
           end
        elseif nargin >= 3
           % Open handle to mount
           CameraObj.HandleMount=MountHn;
           MountConSuccess = CameraObj.HandleMount.connect;
%%%           CameraObj.LogFile.writeLog('Camera connects to mount to get details.')
%%%           if(~MountConSuccess), fprintf('Failed to connect to Mount\n'); end
           if CameraObj.Verbose
               fprintf('>>>>> warning: Focuser was not connected <<<<<\n');
           end
        elseif nargin >= 4
            % Open handle to focuser
            CameraObj.HandleFocuser=FocusHn;
            FocuserConSuccess = CameraObj.HandleFocuser.connect;
%%%            CameraObj.LogFile.writeLog('Camera connects to focuser to derive details.')
%%%            if(~FocuserConSuccess), fprintf('Failed to connect to Focuser\n'); end
        end
%%%%%%%% DP FEB 1        




        % Connect to camera
        success = CameraObj.Handle.connect(CameraNum);
        CameraObj.IsConnected = success;
        if CameraObj.Verbose, fprintf('>>>>> Connecting to camera <<<<<\n'); end

        
        if (success)
            
            % NEEDS TO ADD HERE AN ALGORITM TO CHOOSE WHICH CAMERA TO CONNECT TO. DP 22 Jun 2020
            % - Read 2 Unique names from config file,
            % - Compare with Unique Name read from camera.
            % - Define camera class instance as East or West
            
            % The number of the connected camera for matlab recognition
            CameraObj.CameraNum = CameraObj.Handle.CameraNum;
            
            % Naming of instruments
            
            % Get camera's model and unique name from camera
            CameraNameDetails = strsplit(CameraObj.Handle.CameraName);
            CameraObj.CamUniqueName = CameraNameDetails{end};
            if (strcmp(CameraObj.CamType, 'ZWO'))
                CameraObj.CamModel = CameraObj.Handle.CameraName(1:strfind(CameraObj.Handle.CameraName, CameraObj.CamUniqueName));
            elseif (strcmp(CameraObj.CamType, 'QHY'))
                CameraObj.CamModel = CameraObj.Handle.CameraName(1:strfind(CameraObj.Handle.CameraName, '-')-1);
            end
            
            % get names of all cameras connected to the computer
            % New config file reading (after Dec 2020)
            Fields = fieldnames(ConfigCam);
            for Icam=1:1:length(fieldnames(ConfigCam))
               if(contains(Fields{Icam}, 'CamUniqueName'))
                  if (strcmp(CameraObj.CamUniqueName, eval(['ConfigCam.', Fields{Icam}])))
                     CameraObj.CamGeoName = num2str(Icam);
                  end
               end
            end


            % Old config file reading (before Dec 2020):

%             % Choose an arbitrary high number larger than 2 as the number
%             % of connected cameras
%             NumOfCamerasConnected = 5;
%             for Icam=1:1:NumOfCamerasConnected
%                % Old config file reading (before Dec 2020):
%                CamUniqueNames{Icam} = obs.util.config.readSystemConfigFile(['CamUniqueName',num2str(Icam)]);
%                % Associate Matlab's camera object with physical camera
%                if (strcmp(CameraObj.CamUniqueName, CamUniqueNames{Icam}))
%                   CameraObj.CamGeoName = num2str(Icam);
%                end
%             end
            
            if (strcmp(CameraObj.CamGeoName, ''))
%               fprintf('Cannot recognize the camera %s. It does not appear in the config file: ~/config/ObsSystemConfig.txt\n', CameraObj.CamUniqueName)
               fprintf('Cannot recognize the camera %s. It does not appear in the config file: ~/config/config.camera.txt\n', CameraObj.CamUniqueName)
            end
            
            
            % Read camera Geo name from config file
%%%            CameraObj.CamGeoName = obs.util.config.readSystemConfigFile('CamGeoName');
            
            
            %       % Get searial number of last saved image
            %       BaseDir = '/home/last/images/';
            %       T = celestial.time.jd2date(floor(celestial.time.julday));
            %       DirName = sprintf('%s%d%02d%02d',BaseDir, T(3), T(2), T(1));
            %       if (exist(DirName,'dir'))
            %          cd(DirName);
            %          CameraObj.LastImageSearialNum = length(dir(['*',CameraObj.ImageFormat]));
            %       else
            %          CameraObj.LastImageSearialNum = 0;
            %       end
            

           % Opens Log for the camera
           DirName = obs.util.config.constructDirName('log');
           cd(DirName);

           CameraObj.LogFile = logFile;
           CameraObj.LogFile.Dir = DirName;
% Old version for LogFile name:
%            CameraObj.LogFile.FileNameTemplate = 'LAST_%s.log';
%            CameraObj.LogFile.logOwner = sprintf('%s.%s_%s_Cam', ...
%                      obs.util.config.readSystemConfigFile('ObservatoryNode'),...
%                      obs.util.config.readSystemConfigFile('MountGeoName'),...
%                      DirName(end-7:end));
           CameraObj.LogFile.FileNameTemplate = '%s';
%            CameraObj.LogFile.logOwner = obs.util.config.constructImageName('LAST', ...
%                                                            obs.util.config.readSystemConfigFile('ObservatoryNode'),...
%                                                            obs.util.config.readSystemConfigFile('MountGeoName'),...
%                                                            CameraObj.CamGeoName, datestr(now,'yyyymmdd.HHMMSS.FFF'), ...
%                                                            obs.util.config.readSystemConfigFile('Filter'),...
%                                                            '',      '',     'log',   '',         '',        '1',       'log');
% % legend:                                                  FieldID, ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, ImageFormat

           CameraObj.LogFile.logOwner = obs.util.config.constructImageName('LAST', ...
                                                           num2str(ConfigNode.NodeNumber),...
                                                           num2str(ConfigMount.MountNumber),...
                                                           CameraObj.CamGeoName, datestr(now,'yyyymmdd.HHMMSS.FFF'), ...
                                                           CameraObj.Filter,...
                                                           '',      '',     'log',   '',         '',        '1',       'log');
% legend:                                                  FieldID, ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, ImageFormat

            CameraObj.LogFile.writeLog('~~~~~~~~~~~~~~~~~~~~~~')
            CameraObj.LogFile.writeLog('Camera connected:')
            CameraObj.LogFile.writeLog(sprintf('- CamType: %s',CameraObj.CamType))
            CameraObj.LogFile.writeLog(sprintf('- CamModel: %s',CameraObj.CamModel))
            CameraObj.LogFile.writeLog(sprintf('- CamUniqueName: %s',CameraObj.CamUniqueName))
            CameraObj.LogFile.writeLog(sprintf('- CamGeoName: %s',CameraObj.CamGeoName))
            CameraObj.LogFile.writeLog('~~~~~~~~~~~~~~~~~~~~~~')
            
        else
           if CameraObj.Verbose, fprintf('>>>>> CANNOT CONNECT TO THE CAMERA <<<<<\n'); end
%           CameraObj.LastError = CameraObj.Handle.LastError;
        end
    else
       success = false;
       if CameraObj.Verbose, fprintf('>>>>> A second connecting procedure is NOT allowed <<<<<\n'); end
%       CameraObj.LastError = "A second connecting procedure is NOT allowed";
    end
   
end  % if 1==0



   
end
