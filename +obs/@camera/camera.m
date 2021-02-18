% Camera control handle class (for QHY and ZWO CMOS detectors) 
% Package: +obs
% Description: operate camera drivers.
%              Currently can work with QHY and ZWO detectors
% Input  : CameraType, 'QHY' (default) or 'ZWO'.
%          CameraNum, number of camera to connect with, 1 (default) or 2.
% Output : A camera class
%     By :
% Example: C = obs.camera;              % default is 'QHY'
%          C = obs.camera('QHY');       % With name of camera type
%          C = obs.camera('ZWO', 2);    % with number of camera 
%
% Settings parameters options:
%       C.ExpTime = 1;        % In seconds
%       C.Temperature = 0;    % In Celsius
%       C.CoolingPower = 1;   % On or off
%       C.ImType = 'sci';     % Sci, flat, bias, dark
%       C.Object = 'Jupiter'; % Name of object or field for header
%       C.SaveOnDisk = true;  % To save the image, otherwise: false;
%       C.Display    = 'ds9'; % the software to display the image: ds9, matlab or ''
%       C.DisplayZoom = 0.5;  % decides the zoom ratio to display the image.
%                           % 'All' will present all image
%       C.DisplayReducedIm = true; % Remove the dark and flat field before display
%       C.Handle;             % Direct excess to the driver object

%
% Methods:
%       C.connect;          % Connect to the driver and camera. Options:
%       C.connect(CameraNum, MountHn, FocusHn);
%                           % Connect to specific camera, and drivers of
%                           the mount and focuser.
%       C.takeExposure;     % Take an exposure using ExpTime property
%       C.takeExposure(10); % Take an exposure with 10 seconds
%       C.abort;            % Abort an exposure
%       C.saveCurImage;     % Save last image to disk
%       C.displayImage;     % Display the last image
%       C.coolinOn(Temperature);     % Operate cooling to Temperature
%       C.coolinOff;        % Shut down cooling
%       C.waitFinish;       % Wait for camera status to be Idle
%
%
% Author: David Polishook, Mar 2020
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


classdef camera < obs.LAST_Handle
 
    properties
	% The status of the camera: idle, exposing, reading, unknown
        CamStatus     = 'unknown';

	% The name of the last image 
        LastImageName = '';
	% A matrix of the last image
        LastImage

	% Exposure time
        ExpTime=1;

	% Temperature of the camera
        Temperature = NaN;  % DP -> Put NAN if unknown.
	% The cooling power precentage of the camera
        CoolingPower = NaN;

	% The image type: science, flat, bias, dark
        ImType = 'sci';
	% The name of the observed object/field
        Object = '';
    end

    properties(Hidden)
	% The type of the camera (e.g. QHY)
        CamType       = '';
	% The model of the camera (e.g. QHY-600M-Pro)
        CamModel      = '';
	% Unique name of the specific camera (e.g. 9fc3db42b6306d371)
        CamUniqueName = '';
	% Location of the camera on the mount , to be added to the image name (i.e. 1-4)
        CamGeoName    = '';
	% Number of the camera  as recognized by the computer (i.e. 1-4)
        CameraNum
        
	% Camera readout mode. QHY deault of 1 determines a low readnoise
        ReadMode = 1;
	% The bias level mode of the camera. QHY default is 3
        Offset = 3;
	% The gain of the camera. QHY default is 0
        Gain = 0;
	% The binning of the pixels.
        Binning=[1,1];
	% Used filter. Currenty not implemented
        Filter

	% Reports if colling is on or off
        CoolingStatus = 'unknown';

	% A flag marking if the computer code is connected to the camera
        IsConnected = false;        
	% A flag marking if the images should be wriiten to the disk after exposure
        SaveOnDisk = true; %false;
	% A property defining software to present the image: 'matlab', 'ds9', or '' for no image presentation
        Display    = 'ds9'; %'';
	% When presenting image in matlab, on what figure number to present
        DisplayMatlabFig = 0; % Will be updated after first image
    % Display the entire image, using ds9.zoom
        DisplayAllImage = true;
    % Desired value for ds9.zoom to zoom-in/out
        DisplayZoom = 0.08;
    % Value for ds9.zoom, to present the entire image
        DisplayZoomValueAllImage = 0.08;
    % Remove the dark and flat field before display
        DisplayReducedIm = true;

	% Perhaps obselete. Keep here until we sure it should be removed
        CCDnum = 0;         % ???? 

	% The LogFile object class to handle the log of the camera
        LogFile;
    end

    % Region Of Interest [X1 Y1 X_size Y_size] - currently not implemented
    properties(Dependent = true)
        ROI % beware - SDK does not provide a getter for it, go figure
    end
    
    properties(GetAccess = public, SetAccess = private)
        % Start time and end time of the last integration.
        TimeStart=[];
        TimeEnd=[];
   end
    
    % Properties not implemented yet on this class, but imlpemented[?] in the driver class 
    properties(GetAccess = public, SetAccess = private, Hidden)
        physical_size=struct('chipw',[],'chiph',[],'pixelw',[],'pixelh',[],...
                             'nx',[],'ny',[]);
        effective_area=struct('x1Eff',[],'y1Eff',[],'sxEff',[],'syEff',[]);
        overscan_area=struct('x1Over',[],'y1Over',[],'sxOver',[],'syOver',[]);
        readModesList=struct('name',[],'resx',[],'resy',[]);
        lastExpTime=NaN;
        progressive_frame = 0; % image of a sequence already available
        TimeStartDelta % uncertainty, after-before calling exposure start
    end
    
    % Properties that are not implemented by QHY [is it true?]
    properties(Hidden)
        Color
        BitDepth
    end
    
    properties (Hidden,Transient)
        % A messenger class to comunicate with other computers and matlab
        % instances. See: LAST_Messaging/obs.util.Messenger/@Messenger
%        Messenger;
        % Handle to camera driver class
        Handle;
        % Handle to mount driver class
        HandleMount;
        % Handle to focuser driver class
        HandleFocuser;
        % A timer object to operate after exposure start,  to wait until the image is ready.
        ReadoutTimer;
        % The last error message
        LastError = '';
        % The format of the written image
        ImageFormat = 'fits';
	% Maximum exposure time in seconds
	MaxExpTime = 1800;
        % The serial number of the last image - not implemented anymore
        LastImageSearialNum = 0;
        % A flag marking if to print software printouts or not
        Verbose=true;
        pImg  % pointer to the image buffer (can we gain anything in going
              %  to a double buffer model?)
              % Shall we allocate it only once on open(QC), or, like now,
              %  every time we start an acquisition?
    end

    methods
        % Constructor
        function CameraObj=camera(CamType, CameraNum)

           if nargin >= 2
              CameraObj.CameraNum = CameraNum;
              CameraObj.CamType = CamType;   % 'QHY'; % 'ZWO';
           elseif nargin >= 1
              % Use one camera as default
              CameraObj.CameraNum = 1;
              % Read model of camera
              if (strcmp(CamType,'QHY') || strcmp(CamType,'ZWO'))
                 CameraObj.CamType = CamType;   % 'QHY'; % 'ZWO';
              else
                 error('Use ZWO or QHY cameras only')
              end
           else
              % Use one camera as default
              CameraObj.CameraNum = 1;
              % Use QHY camera as default
              CameraObj.CamType = 'QHY';
           end

% % %            % Opens Log for the camera
% % %            DirName = obs.util.config.constructDirName('log');
% % %            cd(DirName);
% % % 
% % %            CameraObj.LogFile = logFile;
% % %            CameraObj.LogFile.Dir = DirName;
% % %            CameraObj.LogFile.FileNameTemplate = 'LAST_%s.log';
% % %            CameraObj.LogFile.logOwner = sprintf('%s.%s_%s_Cam', ...
% % %                      obs.util.config.readSystemConfigFile('ObservatoryNode'),...
% % %                      obs.util.config.readSystemConfigFile('MountGeoName'),...
% % %                      DirName(end-7:end));
% % %            CameraObj.LogFile.logOwner = constructImageName('LAST', obs.util.config.readSystemConfigFile('ObservatoryNode'),...
% % %                                                            obs.util.config.readSystemConfigFile('MountGeoName'),...
% % %                                                            CameraObj.CamGeoName CamGeoName, ImageDateTime, Filter, FieldID, ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, ImageFormat);



% Should the log be for 1 or 2 cameras??? Here is for a single camera:
%           CameraObj.LogFile.logOwner = sprintf('%s.%s.%s_%s_Cam', ...
%                     obs.util.config.readSystemConfigFile('ObservatoryNode'),...
%                     obs.util.config.readSystemConfigFile('MountGeoName'),...
%                     obs.util.config.readSystemConfigFile('CamGeoName'), DirName(end-7:end));

            % Open a driver object for the camera
            if(strcmp(CameraObj.CamType, 'ZWO'))
               CameraObj.Handle=inst.ZWOASICamera(CameraObj.CameraNum);
            elseif(strcmp(CameraObj.CamType, 'QHY'))
               CameraObj.Handle=inst.QHYccd(CameraObj.CameraNum);
            end

            % Check if a camera was not found
            CameraObj.LastError = CameraObj.Handle.LastError;

            % Update filter and ccd number from config file
            % Old config file reading (before Dec 2020):
%             CameraObj.Filter = obs.util.config.readSystemConfigFile('Filter');
%             CameraObj.CCDnum = obs.util.config.readSystemConfigFile('CCDnum');
            % New config file reading (after Dec 2020):
            Config=obs.util.config.read_config_file('/home/last/config/config.camera.txt');
            % Even newer config file reading (Feb 15 2021):
            ConfigCam = configfile.read_config('config.camera_1_1_1.txt');
            CameraObj.Filter = ConfigCam.Filter;
            CameraObj.CCDnum = Config.CCDnum;  % DP - REPLACE BY READING ConfigCam

        end

        % Destructor
        function delete(CameraObj)
           % Delete properly driver object
            CameraObj.Handle.delete;
        end
    end
    
    methods % Getters and setters
        
	% Get image type
        function ImType=get.ImType(CameraObj)
            ImType=CameraObj.ImType;
        end
        
	% set image type
        function set.ImType(CameraObj,ImType)
            CameraObj.ImType = ImType;
            CameraObj.LogFile.writeLog(sprintf('call set.ImType. ImType=%s',ImType))
        end

        % Get image object
        function Object=get.Object(CameraObj)
            Object=CameraObj.Object;
        end

        % Set image object
        function set.Object(CameraObj,Object)
            CameraObj.Object = Object;
            CameraObj.LogFile.writeLog(sprintf('call set.Object. Object=%s', Object))
        end

	% Get camera status: idle, exposing, reading, unknown
        function status=get.CamStatus(CameraObj)
            status = 'unknown';
            if CameraObj.checkIfConnected
               status=CameraObj.Handle.CamStatus;
               CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end

	% Get the camera cooling status: on, off
        function status=get.CoolingStatus(CameraObj)
            if CameraObj.checkIfConnected
               status = CameraObj.Handle.CoolingStatus;
               CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end

        % Get the last image taken
        function LastImage=get.LastImage(CameraObj)
            if CameraObj.checkIfConnected
               LastImage = CameraObj.Handle.LastImage;
            end
        end

	% Get the current temperature of the camera, in Celsius
        function Temp=get.Temperature(CameraObj)
            if CameraObj.checkIfConnected
               Temp = CameraObj.Handle.Temperature;
               CameraObj.LastError = CameraObj.Handle.LastError;
            else
               Temp = NaN;
            end
        end

	% Set the temperature of the camera. Input: temperature in Celsius
        function set.Temperature(CameraObj,Temp)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.Temperature. Temperature=%f',Temp))
               CameraObj.Handle.Temperature = Temp;
               CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end

	% Get the precentage of the cooling power
        function CoolingPower=get.CoolingPower(CameraObj)
            if CameraObj.checkIfConnected
               CoolingPower = CameraObj.Handle.CoolingPower;
               CameraObj.LastError = CameraObj.Handle.LastError;
            else
               CoolingPower = NaN;
            end
        end

	% Get the exposure time. In seconds
        function ExpTime=get.ExpTime(CameraObj)
            if CameraObj.checkIfConnected
               ExpTime = CameraObj.Handle.ExpTime;
               CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end

	% Set the exposure time for the next exposure. In seconds
        function set.ExpTime(CameraObj,ExpTime)
	       if (ExpTime <= CameraObj.MaxExpTime)
              if CameraObj.checkIfConnected
                 CameraObj.LogFile.writeLog(sprintf('call set.ExpTime. ExpTime=%f',ExpTime))
                 CameraObj.Handle.ExpTime = ExpTime;
                 CameraObj.LastError = CameraObj.Handle.LastError;
              end
           else
	          CameraObj.LastError = 'Exposure time is too long. Probably a mistake. Did not change time';
           end
        end

        % Get the start time of the last image.
        function TimeStart=get.TimeStart(CameraObj)
            if CameraObj.checkIfConnected
               TimeStart = CameraObj.Handle.TimeStart;
               CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end

	% Get the end time of the last image.
        function TimeEnd=get.TimeEnd(CameraObj)
            if CameraObj.checkIfConnected
               TimeEnd = CameraObj.Handle.TimeEnd;
               CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end

	% Get the gain value of the camera
        function Gain=get.Gain(CameraObj)
           if CameraObj.checkIfConnected
              Gain = CameraObj.Handle.Gain;
              CameraObj.LastError = CameraObj.Handle.LastError;
           end
        end

        % Set the gain value of the camera
        function set.Gain(CameraObj,Gain)
           if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.Gain. Gain=%f',Gain))
               % for an explanation of gain & offset vs. dynamics, see
               %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
               %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
               CameraObj.Handle.Gain = Gain;
               CameraObj.LastError = CameraObj.Handle.LastError;
           end
        end

        % ROI - assuming that this is what the SDK calls "Resolution"
        function set.ROI(CameraObj,roi)
            % resolution is [x1,y1,sizex,sizey]
            %  I highly suspect that this setting is very problematic
            %   especially in color mode.
           if CameraObj.checkIfConnected
              CameraObj.LogFile.writeLog(sprintf('call set.ROI. roi=%f',roi))
              CameraObj.Handle.ROI = roi;
              CameraObj.LastError = CameraObj.Handle.LastError;
           end
        end

	% Get the offset value, i.e. the bias level of the camera. Values are unique to this system
        function Offset=get.Offset(CameraObj)
           if CameraObj.checkIfConnected
              Offset = CameraObj.Handle.Offset;
              CameraObj.LastError = CameraObj.Handle.LastError;
           end
        end

        function set.Offset(CameraObj,Offset)
           if CameraObj.checkIfConnected
              CameraObj.LogFile.writeLog(sprintf('call set.Offset. Offset=%f',Offset))
              CameraObj.Handle.Offset = Offset;
              CameraObj.LastError = CameraObj.Handle.LastError;
           end
        end

        function readMode=get.ReadMode(CameraObj)
           if CameraObj.checkIfConnected
              readMode = CameraObj.Handle.ReadMode;
              CameraObj.LastError = CameraObj.Handle.LastError;
           end
       end

        function set.ReadMode(CameraObj,ReadMode)
           if CameraObj.checkIfConnected
              CameraObj.LogFile.writeLog(sprintf('call set.ReadMode. readMode=%f',ReadMode))
              CameraObj.Handle.ReadMode = ReadMode;
              CameraObj.LastError = CameraObj.Handle.LastError;
           end
        end

        function set.Binning(CameraObj,Binning)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.Binning. Binning=%f',Binning))
               % default is 1x1
               % for the QHY367, 1x1 and 2x2 seem to work; NxN with N>2 gives
               % error.
               CameraObj.Handle.Binning = Binning;
               CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end
        
        % The SDK doesn't provide a function for getting the current
        %  binning, go figure

        function set.Color(CameraObj,ColorMode)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.Color. ColorMode=%f',ColorMode))
               % default has to be bw
               CameraObj.Handle.Color = ColorMode;
               CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end

        function set.BitDepth(CameraObj,BitDepth)
            if CameraObj.checkIfConnected
                CameraObj.LogFile.writeLog(sprintf('call set.BitDepth. BitDepth=%f',BitDepth))
                % BitDepth: 8 or 16 (bit). My understanding is that this is in
                %  first place a communication setting, which however implies
                %  the scaling of the raw ADC readout. IIUC, e.g. a 14bit ADC
                %  readout is upshifted to full 16 bit range in 16bit mode.
                % Constrain BitDepth to 8|16, the functions wouldn't give any
                %  error anyway for different values.
                % default has to be bw
                CameraObj.Handle.BitDepth = BitDepth;
                CameraObj.LastError = CameraObj.Handle.LastError;
            end
        end

        function BitDepth=get.BitDepth(CameraObj)
           if CameraObj.checkIfConnected
              BitDepth = CameraObj.Handle.BitDepth;
              CameraObj.LastError = CameraObj.Handle.LastError;
           end
        end

        % Get the last error reported by the driver code
        function LastError=get.LastError(CameraObj)
            LastError = CameraObj.Handle.LastError;
            CameraObj.LogFile.writeLog(LastError)
            if CameraObj.Verbose, fprintf('%s\n', LastError); end
        end

        % Set an error message, update log and print to command line
        function set.LastError(CameraObj,LastError)
           % If the LastError is empty (e.g. if the previous command did
           % not fail), do not keep or print it,
           if (~isempty(LastError))
              % If the error message is taken from the driver object, do NOT
              % update the driver object.
%              if (~strcmp(CameraObj.Handle.LastError, LastError))
%                 CameraObj.Handle.LastError = LastError;
%              end
              CameraObj.LogFile.writeLog(LastError)
              if CameraObj.Verbose, fprintf('%s\n', LastError); end
           end
        end
        
        % Set the display zoom value
        function set.DisplayZoom(CameraObj,ZoomValue)
           if (strcmp(ZoomValue,'All'))
              ZoomValue = CameraObj.DisplayZoomValueAllImage;
              CameraObj.DisplayAllImage = true;
           else
              CameraObj.DisplayAllImage = false;
           end
           CameraObj.DisplayZoom = ZoomValue;
        end

        % Set the DisplayAllImage flag
        function set.DisplayAllImage(CameraObj,Flag)
           CameraObj.DisplayAllImage = Flag;
           if(Flag)
              CameraObj.DisplayZoomValue = CameraObj.DisplayZoomValueAllImage;
           end
        end

    end
    
end
