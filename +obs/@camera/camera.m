% Camera control handle class (for QHY and ZWO CMOS detectors) 
% Package: +obs
% Description: operate drivers of QHY and ZWO detectors

classdef camera < handle
 
    properties
        CamStatus     = 'unknown';

        LastImageName = '';
        LastImage

        ExpTime=10;

        Temperature  % DP -> Put NAN if unknown.
        CoolingPower = NaN;

        ImType = 'science';
        Object = '';
    end

    properties(Hidden)
        CamType       = '';
        CamModel      = '';
        CamUniqueName = '';
        CamGeoName    = '';
        CameraNum
        
        ReadMode
        Offset
        Gain=0;
        Binning=[1,1];
        Filter

        CoolingStatus = 'unknown';

        IsConnected = false;        
        SaveOnDisk = true; %false;
        Display    = 'ds9'; %'';
        DisplayMatlabFig = 0; % Will be updated after first image

        CCDnum = 0;         % ???? 
        LogFile;
    end
        
    properties(Dependent = true)
        ROI % beware - SDK does not provide a getter for it, go figure
    end
    
    properties(GetAccess = public, SetAccess = private)
%         time_start=[];
%         time_end=[];
   end
    
    % Enrico, discretional
    properties(GetAccess = public, SetAccess = private, Hidden)
        physical_size=struct('chipw',[],'chiph',[],'pixelw',[],'pixelh',[],...
                             'nx',[],'ny',[]);
        effective_area=struct('x1Eff',[],'y1Eff',[],'sxEff',[],'syEff',[]);
        overscan_area=struct('x1Over',[],'y1Over',[],'sxOver',[],'syOver',[]);
        readModesList=struct('name',[],'resx',[],'resy',[]);
        lastExpTime=NaN;
        progressive_frame = 0; % image of a sequence already available
        time_start_delta % uncertainty, after-before calling exposure start
    end
    
    % settings which have not been prescribed by the API,
    % but for which I have already made the code
    properties(Hidden)
        Color
        BitDepth
    end
    
    properties (Hidden,Transient)
        Handle;      % Handle to camera driver class
        HandleMount;      % Handle to mount driver class
        HandleFocuser;      % Handle to focuser driver class
        ReadoutTimer;
        LastError = '';
        ImageFormat = 'fits';
        LastImageSearialNum = 0;
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

           % Opens Log for the camera
           DirName = obs.util.config.constructDirName('log');
           cd(DirName);

           CameraObj.LogFile = logFile;
           CameraObj.LogFile.Dir = DirName;
           CameraObj.LogFile.FileNameTemplate = 'LAST_%s.log';
           CameraObj.LogFile.logOwner = sprintf('%s.%s_%s_Cam', ...
                     obs.util.config.readSystemConfigFile('ObservatoryNode'),...
                     obs.util.config.readSystemConfigFile('MountGeoName'),...
                     DirName(end-7:end));
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

            % Check if a camera was found
            CameraObj.LastError = CameraObj.Handle.lastError;

            % Update filter and ccd number from config file
            CameraObj.Filter = obs.util.config.readSystemConfigFile('Filter');
            CameraObj.CCDnum = obs.util.config.readSystemConfigFile('CCDnum');
            
        end

        % Destructor
        function delete(CameraObj)
           % Delete properly driver object
            CameraObj.Handle.delete;
        end
    end
    
    methods %getters and setters
        
        function ImType=get.ImType(CameraObj)
            ImType=CameraObj.ImType;
        end
        
        function set.ImType(CameraObj,ImType)
            CameraObj.ImType = ImType;
            CameraObj.LogFile.writeLog(sprintf('call set.ImType. ImType=%s',ImType))
        end

        function status=get.CamStatus(CameraObj)
            status = 'unknown';
            if CameraObj.checkIfConnected
               status=CameraObj.Handle.CamStatus;
               CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end
        
        function status=get.CoolingStatus(CameraObj)
            if CameraObj.checkIfConnected
               status = CameraObj.Handle.CoolingStatus;
               CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end        
        
        function LastImage=get.LastImage(CameraObj)
            if CameraObj.checkIfConnected
               LastImage = CameraObj.Handle.lastImage;
            end
        end

        function Temp=get.Temperature(CameraObj)
            if CameraObj.checkIfConnected
               Temp = CameraObj.Handle.Temperature;
               CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end

        function set.Temperature(CameraObj,Temp)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.Temperature. Temperature=%f',Temp))
               CameraObj.Handle.Temperature = Temp;
               CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end
        
        function CoolingPower=get.CoolingPower(CameraObj)
            if CameraObj.checkIfConnected
               CoolingPower = CameraObj.Handle.CoolingPower;
               CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end
        
        function ExpTime=get.ExpTime(CameraObj)
            if CameraObj.checkIfConnected
               % ExpTime in seconds
               ExpTime = CameraObj.Handle.ExpTime;
               CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end

        function set.ExpTime(CameraObj,ExpTime)
           if CameraObj.checkIfConnected
               % ExpTime in seconds
               CameraObj.LogFile.writeLog(sprintf('call set.ExpTime. ExpTime=%f',ExpTime))
               CameraObj.Handle.ExpTime = ExpTime;
               CameraObj.LastError = CameraObj.Handle.lastError;
           end
        end
        
        function Gain=get.Gain(CameraObj)
           if CameraObj.checkIfConnected
              Gain = CameraObj.Handle.Gain;
              CameraObj.LastError = CameraObj.Handle.lastError;
           end
        end
        
        function set.Gain(CameraObj,Gain)
           if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.Gain. Gain=%f',Gain))
               % for an explanation of gain & offset vs. dynamics, see
               %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
               %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
               CameraObj.Handle.Gain = Gain;
               CameraObj.LastError = CameraObj.Handle.lastError;
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
              CameraObj.LastError = CameraObj.Handle.lastError;
           end
        end

        function offset=get.Offset(CameraObj)
           if CameraObj.checkIfConnected
              % Offset seems to be a sort of bias, black level
              offset = CameraObj.Handle.offset;
              CameraObj.LastError = CameraObj.Handle.lastError;
           end
        end

        function set.Offset(CameraObj,offset)
           if CameraObj.checkIfConnected
              CameraObj.LogFile.writeLog(sprintf('call set.Offset. offset=%f',offset))
              CameraObj.Handle.offset = offset;
              CameraObj.LastError = CameraObj.Handle.lastError;
           end
        end

        function readMode=get.ReadMode(CameraObj)
           if CameraObj.checkIfConnected
              readMode = CameraObj.Handle.ReadMode;
              CameraObj.LastError = CameraObj.Handle.lastError;
           end
       end

        function set.ReadMode(CameraObj,ReadMode)
           if CameraObj.checkIfConnected
              CameraObj.LogFile.writeLog(sprintf('call set.ReadMode. readMode=%f',readMode))
              CameraObj.Handle.ReadMode = ReadMode;
              CameraObj.LastError = CameraObj.Handle.lastError;
           end
        end

        function set.Binning(CameraObj,Binning)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.binning. binning=%f',binning))
               % default is 1x1
               % for the QHY367, 1x1 and 2x2 seem to work; NxN with N>2 gives
               % error.
               CameraObj.Handle.binning = Binning;
               CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end
        
        % The SDK doesn't provide a function for getting the current
        %  binning, go figure

        function set.Color(CameraObj,ColorMode)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.color. ColorMode=%f',ColorMode))
               % default has to be bw
               CameraObj.Handle.color = ColorMode;
               CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end

        function set.BitDepth(CameraObj,BitDepth)
            if CameraObj.checkIfConnected
                CameraObj.LogFile.writeLog(sprintf('call set.bitDepth. BitDepth=%f',BitDepth))
                % BitDepth: 8 or 16 (bit). My understanding is that this is in
                %  first place a communication setting, which however implies
                %  the scaling of the raw ADC readout. IIUC, e.g. a 14bit ADC
                %  readout is upshifted to full 16 bit range in 16bit mode.
                % Constrain BitDepth to 8|16, the functions wouldn't give any
                %  error anyway for different values.
                % default has to be bw
                CameraObj.Handle.bitDepth = BitDepth;
                CameraObj.LastError = CameraObj.Handle.lastError;
            end
        end

        function BitDepth=get.BitDepth(CameraObj)
           if CameraObj.checkIfConnected
              BitDepth = CameraObj.Handle.bitDepth;
              CameraObj.LastError = CameraObj.Handle.lastError;
           end
        end

        % Get the last error reported by the driver code
        function LastError=get.LastError(CameraObj)
            LastError = CameraObj.Handle.lastError;
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
%              if (~strcmp(CameraObj.Handle.lastError, LastError))
%                 CameraObj.Handle.lastError = LastError;
%              end
              CameraObj.LogFile.writeLog(LastError)
              if CameraObj.Verbose, fprintf('%s\n', LastError); end
           end
        end

    end
    
end