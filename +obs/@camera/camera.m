% Camera control handle class (for QHY and ZWO CMOS detectors) 
% Package: +obs
% Description: operate drivers of QHY and ZWO detectors

classdef camera < handle
 
    properties
        CamType       = NaN;
        CamModel      = NaN;
        CamUniqueName = NaN;
        CamGeoName    = NaN;
        CamStatus     = NaN;
        CoolingStatus = NaN;
        
        
        CoolingPercentage = NaN;
        cameranum
        binning=[1,1];
        ExpTime=10;
        Gain=0;
        SaveOnDisk = false;
        Display    = false;
        LastImageName
        Filter
        CCDnum = 0;
        ImType = 'science';
        Object;
        LogFile;
    end

    properties(Transient)
    end
        
    properties(Dependent = true)
        Temperature
        ROI % beware - SDK does not provide a getter for it, go figure
        ReadMode
        Offset
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
        lastError='';
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

           if exist('CamType','var')
              if (strcmp(CamType,'QHY') | strcmp(CamType,'ZWO'))
                 CameraObj.CamType = CamType;   % 'QHY'; % 'ZWO';
              else
                 error('Use ZWO or QHY cameras only')
              end
           else
              % Use ZWO camera as default
              CameraObj.CamType = 'ZWO';
           end

           DirName = util.constructDirName();
           cd(DirName);

           % Opens Log for the camera
           CameraObj.LogFile = logFile;
           CameraObj.LogFile.Dir = DirName;
           CameraObj.LogFile.FileNameTemplate = 'LAST_%s.log';
           CameraObj.LogFile.logOwner = sprintf('%s.%s.%s_%s_Cam', ...
                     util.readSystemConfigFile('ObservatoryNode'), util.readSystemConfigFile('MountGeoName'), util.readSystemConfigFile('CamGeoName'), DirName(end-7:end));

            % Open a driver object for the camera
            if(strcmp(CameraObj.CamType, 'ZWO'))
               CameraObj.CamHn=inst.ZWOASICamera();
            elseif(strcmp(CameraObj.CamType, 'QHY'))
               CameraObj.CamHn=inst.QHYccd();
            end

            switch CameraObj.CamHn.lastError
                case "could not even get one camera id"
                    CameraObj.lastError = "Could not even get one camera id";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            
            CameraObj.Filter = util.readSystemConfigFile('Filter');
            CameraObj.CCDnum = util.readSystemConfigFile('CCDnum');
            
        end

        % Destructor
        function delete(CameraObj)
            
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
            status=CameraObj.CamHn.CamStatus;
        end
        
        function status=get.CoolingStatus(CameraObj)
            status = CameraObj.CamHn.CoolingStatus;
        end
        
        
        function Temp=get.Temperature(CameraObj)
            Temp = CameraObj.CamHn.Temperature;
            switch CameraObj.CamHn.lastError
                case "could not get temperature"
                    CameraObj.lastError = "Could not get temperature";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
        end

        function set.Temperature(CameraObj,Temp)
            CameraObj.CamHn.Temperature = Temp;
            switch CameraObj.CamHn.lastError
                case "could not get temperature"
                    CameraObj.lastError = "Could not get temperature";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            CameraObj.LogFile.writeLog(sprintf('call set.Temperature. Temperature=%f',Temp))
        end
        
        function Percentage=get.CoolingPercentage(CameraObj)
           Percentage = CameraObj.CamHn.CoolingPercentage;
        end


        
        function ExpTime=get.ExpTime(CameraObj)
            % ExpTime in seconds
            ExpTime = CameraObj.CamHn.ExpTime;
            switch CameraObj.CamHn.lastError
                case "could not get exposure time"
                    CameraObj.lastError = "Could not get exposure time";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
        end

        function set.ExpTime(CameraObj,ExpTime)
            % ExpTime in seconds
            CameraObj.CamHn.ExpTime = ExpTime;
            switch CameraObj.CamHn.lastError
                case "could not set exposure time"
                    CameraObj.lastError = "Could not set exposure time";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            CameraObj.LogFile.writeLog(sprintf('call set.ExpTime. ExpTime=%f',ExpTime))
        end

        
        function Gain=get.Gain(CameraObj)
            Gain = CameraObj.CamHn.Gain;
            switch CameraObj.CamHn.lastError
                case "could not get gain"
                    CameraObj.lastError = "Could not get gain";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
        end
        
        function set.Gain(CameraObj,Gain)
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            CameraObj.CamHn.Gain = Gain;
            switch CameraObj.CamHn.lastError
                case "could not set gain"
                    CameraObj.lastError = "Could not set gain";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            CameraObj.LogFile.writeLog(sprintf('call set.Gain. Gain=%f',Gain))
        end
        
        
        % ROI - assuming that this is what the SDK calls "Resolution"
        function set.ROI(CameraObj,roi)
            % resolution is [x1,y1,sizex,sizey]
            %  I highly suspect that this setting is very problematic
            %   especially in color mode.
            CameraObj.CamHn.ROI = roi;
            switch CameraObj.CamHn.lastError
                case "could not set ROI"
                    CameraObj.lastError = "Could not set ROI";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            CameraObj.LogFile.writeLog(sprintf('call set.ROI. roi=%f',roi))
        end

        
        function offset=get.Offset(CameraObj)
            % Offset seems to be a sort of bias, black level
            offset = CameraObj.CamHn.offset;
            switch CameraObj.CamHn.lastError
                case "could not get offset"
                    CameraObj.lastError = "Could not get offset";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
        end
        
        function set.Offset(CameraObj,offset)
            CameraObj.CamHn.offset = offset;
            switch CameraObj.CamHn.lastError
                case "could not set offset"
                    CameraObj.lastError = "Could not set offset";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            CameraObj.LogFile.writeLog(sprintf('call set.Offset. offset=%f',offset))
        end

        
        function readMode=get.ReadMode(CameraObj)
            readMode = CameraObj.CamHn.readMode;
            switch CameraObj.CamHn.lastError
                case "could not get the read mode"
                    CameraObj.lastError = "Could not get read mode";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
        end

        function set.ReadMode(CameraObj,readMode)
            CameraObj.CamHn.readMode = readMode;
            switch CameraObj.CamHn.lastError
                case "could not set the read mode"
                    CameraObj.lastError = "Could not set read mode";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            CameraObj.LogFile.writeLog(sprintf('call set.ReadMode. readMode=%f',readMode))
        end


        function set.binning(CameraObj,binning)
            % default is 1x1
            % for the QHY367, 1x1 and 2x2 seem to work; NxN with N>2 gives
            % error.
            CameraObj.CamHn.binning = binning;
            switch CameraObj.CamHn.lastError
                case "could not set the binning"
                    CameraObj.lastError = "Could not set binning";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            CameraObj.LogFile.writeLog(sprintf('call set.binning. binning=%f',binning))
        end
        
        % The SDK doesn't provide a function for getting the current
        %  binning, go figure

        function set.color(CameraObj,ColorMode)
            % default has to be bw
            CameraObj.CamHn.binning = ColorMode;
            switch CameraObj.CamHn.lastError
                case "could not set the binning"
                    CameraObj.lastError = "Could not set color mode";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
            CameraObj.LogFile.writeLog(sprintf('call set.color. ColorMode=%f',ColorMode))
        end

        function set.bitDepth(CameraObj,BitDepth)
            % BitDepth: 8 or 16 (bit). My understanding is that this is in
            %  first place a communication setting, which however implies
            %  the scaling of the raw ADC readout. IIUC, e.g. a 14bit ADC
            %  readout is upshifted to full 16 bit range in 16bit mode.
            % Constrain BitDepth to 8|16, the functions wouldn't give any
            %  error anyway for different values.
            % default has to be bw
            CameraObj.CamHn.binning = BitDepth;
            switch CameraObj.CamHn.lastError
                case "could not set bit depth"
                    CameraObj.lastError = "Could not set bit depth";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end    
            CameraObj.LogFile.writeLog(sprintf('call set.bitDepth. BitDepth=%f',BitDepth))
        end

        function bitDepth=get.bitDepth(CameraObj)
            bitDepth = CameraObj.CamHn.bitDepth;
            switch CameraObj.CamHn.lastError
                case "could not get bit depth"
                    CameraObj.lastError = "Could not get bit depth";
                    if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
                    CameraObj.LogFile.writeLog(CameraObj.lastError)
            end
        end

    end
    
end