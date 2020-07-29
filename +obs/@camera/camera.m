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
        cameranum
        
        ReadMode
        Offset
        Gain=0;
        binning=[1,1];
        Filter

        CoolingStatus = 'unknown';

        IsConnected = false;        
        SaveOnDisk = true; %false;
        Display    = 'ds9'; %'';

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
        color
        bitDepth
    end
    
    properties (Hidden,Transient)
        CamHn;      % Handle to camera driver class
        MouHn;      % Handle to mount driver class
        FocHn;      % Handle to focuser driver class
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
        function CameraObj=camera(CamType)

           if nargin >= 1
              if (strcmp(CamType,'QHY') | strcmp(CamType,'ZWO'))
                 CameraObj.CamType = CamType;   % 'QHY'; % 'ZWO';
              else
                 error('Use ZWO or QHY cameras only')
              end
           else
              % Use ZWO camera as default
              CameraObj.CamType = 'ZWO';
           end

           DirName = obs.util.constructDirName('log');
           cd(DirName);

           % Opens Log for the camera
           CameraObj.LogFile = logFile;
           CameraObj.LogFile.Dir = DirName;
           CameraObj.LogFile.FileNameTemplate = 'LAST_%s.log';
           CameraObj.LogFile.logOwner = sprintf('%s.%s.%s_%s_Cam', ...
                     obs.util.readSystemConfigFile('ObservatoryNode'), obs.util.readSystemConfigFile('MountGeoName'), obs.util.readSystemConfigFile('CamGeoName'), DirName(end-7:end));

            % Open a driver object for the camera
            if(strcmp(CameraObj.CamType, 'ZWO'))
               CameraObj.CamHn=inst.ZWOASICamera();
            elseif(strcmp(CameraObj.CamType, 'QHY'))
               CameraObj.CamHn=inst.QHYccd();
            end

            % Check if a camera was found
            CameraObj.LastError = CameraObj.CamHn.lastError;

            % Update filter and ccd number from config file
            CameraObj.Filter = obs.util.readSystemConfigFile('Filter');
            CameraObj.CCDnum = obs.util.readSystemConfigFile('CCDnum');
            
        end

        % Destructor
        function delete(CameraObj)
           % Delete properly driver object
            CameraObj.CamHn.delete;
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
               status=CameraObj.CamHn.CamStatus;
               CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end
        
        function status=get.CoolingStatus(CameraObj)
            if CameraObj.checkIfConnected
               status = CameraObj.CamHn.CoolingStatus;
               CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end        
        
        function LastImage=get.LastImage(CameraObj)
            if CameraObj.checkIfConnected
               LastImage = CameraObj.CamHn.lastImage;
            end
        end

        function Temp=get.Temperature(CameraObj)
            if CameraObj.checkIfConnected
               Temp = CameraObj.CamHn.Temperature;
               CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end

        function set.Temperature(CameraObj,Temp)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.Temperature. Temperature=%f',Temp))
               CameraObj.CamHn.Temperature = Temp;
               CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end
        
        function CoolingPower=get.CoolingPower(CameraObj)
            if CameraObj.checkIfConnected
               CoolingPower = CameraObj.CamHn.CoolingPower;
               CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end
        
        function ExpTime=get.ExpTime(CameraObj)
            if CameraObj.checkIfConnected
               % ExpTime in seconds
               ExpTime = CameraObj.CamHn.ExpTime;
               CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end

        function set.ExpTime(CameraObj,ExpTime)
           if CameraObj.checkIfConnected
               % ExpTime in seconds
               CameraObj.LogFile.writeLog(sprintf('call set.ExpTime. ExpTime=%f',ExpTime))
               CameraObj.CamHn.ExpTime = ExpTime;
               CameraObj.LastError = CameraObj.CamHn.lastError;
           end
        end
        
        function Gain=get.Gain(CameraObj)
           if CameraObj.checkIfConnected
              Gain = CameraObj.CamHn.Gain;
              CameraObj.LastError = CameraObj.CamHn.lastError;
           end
        end
        
        function set.Gain(CameraObj,Gain)
           if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.Gain. Gain=%f',Gain))
               % for an explanation of gain & offset vs. dynamics, see
               %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
               %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
               CameraObj.CamHn.Gain = Gain;
               CameraObj.LastError = CameraObj.CamHn.lastError;
           end
        end
        
        % ROI - assuming that this is what the SDK calls "Resolution"
        function set.ROI(CameraObj,roi)
            % resolution is [x1,y1,sizex,sizey]
            %  I highly suspect that this setting is very problematic
            %   especially in color mode.
           if CameraObj.checkIfConnected
              CameraObj.LogFile.writeLog(sprintf('call set.ROI. roi=%f',roi))
              CameraObj.CamHn.ROI = roi;
              CameraObj.LastError = CameraObj.CamHn.lastError;
           end
        end

        function offset=get.Offset(CameraObj)
           if CameraObj.checkIfConnected
              % Offset seems to be a sort of bias, black level
              offset = CameraObj.CamHn.offset;
              CameraObj.LastError = CameraObj.CamHn.lastError;
           end
        end

        function set.Offset(CameraObj,offset)
           if CameraObj.checkIfConnected
              CameraObj.LogFile.writeLog(sprintf('call set.Offset. offset=%f',offset))
              CameraObj.CamHn.offset = offset;
              CameraObj.LastError = CameraObj.CamHn.lastError;
           end
        end

        function readMode=get.ReadMode(CameraObj)
           if CameraObj.checkIfConnected
              readMode = CameraObj.CamHn.ReadMode;
              CameraObj.LastError = CameraObj.CamHn.lastError;
           end
       end

        function set.ReadMode(CameraObj,ReadMode)
           if CameraObj.checkIfConnected
              CameraObj.LogFile.writeLog(sprintf('call set.ReadMode. readMode=%f',readMode))
              CameraObj.CamHn.ReadMode = ReadMode;
              CameraObj.LastError = CameraObj.CamHn.lastError;
           end
        end

        function set.binning(CameraObj,binning)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.binning. binning=%f',binning))
               % default is 1x1
               % for the QHY367, 1x1 and 2x2 seem to work; NxN with N>2 gives
               % error.
               CameraObj.CamHn.binning = binning;
               CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end
        
        % The SDK doesn't provide a function for getting the current
        %  binning, go figure

        function set.color(CameraObj,ColorMode)
            if CameraObj.checkIfConnected
               CameraObj.LogFile.writeLog(sprintf('call set.color. ColorMode=%f',ColorMode))
               % default has to be bw
               CameraObj.CamHn.binning = ColorMode;
               CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end

        function set.bitDepth(CameraObj,BitDepth)
            if CameraObj.checkIfConnected
                CameraObj.LogFile.writeLog(sprintf('call set.bitDepth. BitDepth=%f',BitDepth))
                % BitDepth: 8 or 16 (bit). My understanding is that this is in
                %  first place a communication setting, which however implies
                %  the scaling of the raw ADC readout. IIUC, e.g. a 14bit ADC
                %  readout is upshifted to full 16 bit range in 16bit mode.
                % Constrain BitDepth to 8|16, the functions wouldn't give any
                %  error anyway for different values.
                % default has to be bw
                CameraObj.CamHn.binning = BitDepth;
                CameraObj.LastError = CameraObj.CamHn.lastError;
            end
        end

        function bitDepth=get.bitDepth(CameraObj)
           if CameraObj.checkIfConnected
              bitDepth = CameraObj.CamHn.bitDepth;
              CameraObj.LastError = CameraObj.CamHn.lastError;
           end
        end

        % Get the last error reported by the driver code
        function LastError=get.LastError(CameraObj)
            LastError = CameraObj.CamHn.lastError;
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
              if (~strcmp(CameraObj.CamHn.lastError, LastError))
                 CameraObj.CamHn.lastError = LastError;
              end
              CameraObj.LogFile.writeLog(LastError)
              if CameraObj.Verbose, fprintf('%s\n', LastError); end
           end
        end

    end
    
end