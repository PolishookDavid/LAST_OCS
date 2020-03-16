classdef camera < handle
 
    properties
        cameranum
        % read/write properties, settings of the camera, for which
        %  hardware query is involved.
        %  We use getters/setters, even though instantiation
        %   order is not guaranteed. In particular, all parameters
        %   of the camera require that camhandle is obtained first.
        %  Values set here as default won't likely be passed to the camera
        %   when the object is created
        binning=[1,1]; % beware - SDK does not provide a getter for it, go figure
        ExpTime=10;
        Gain=0;
    end

    properties(Transient)
        lastImage
    end
        
    properties(Dependent = true)
        Temperature
        ROI % beware - SDK does not provide a getter for it, go figure
        ReadMode
        offset
    end
    
    properties(GetAccess = public, SetAccess = private)
        CameraName
        CamStatus='unknown';
        CoolingStatus
        time_start=[];
        time_end=[];
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
        CameraDriverHndl = NaN;
        ReadoutTimer;
        lastError='';
        verbose=true;
        pImg  % pointer to the image buffer (can we gain anything in going
              %  to a double buffer model?)
              % Shall we allocate it only once on open(QC), or, like now,
              %  every time we start an acquisition?
    end

    methods
        % Constructor
        function CameraObj=camera()

            % Open a driver object for the mount
            CameraObj.CameraDriverHndl=inst.QHYccd();
            
            switch CameraObj.CameraDriverHndl.lastError
                case "could not even get one camera id"
                    CameraObj.lastError = "could not even get one camera id";
            end
            
        end

        % Destructor
        function delete(CameraObj)
            
            CameraObj.CameraDriverHndl.delete;
            
            switch CameraObj.CameraDriverHndl.lastError
                case "could not close camera"
                    CameraObj.lastError = "could not close camera";
            end
            
            % but:
            % don't release the SDK, other QC objects may be using it
            % Besides, releasing prevents reopening
            % ReleaseQHYCCDResource;
            
        end
        
    end
    
    methods %getters and setters
        
        function status=get.CamStatus(CameraObj)
            status=CameraObj.CameraDriverHndl.CamStatus;
        end
        
        function status=get.CoolingStatus(QC)
            status = CameraObj.CameraDriverHndl.CoolingStatus;
        end
        
        
        function Temp=get.Temperature(CameraObj)
            Temp = CameraObj.CameraDriverHndl.Temp;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not get temperature"
                    CameraObj.lastError = "could not get temperature";
            end
        end

        function set.Temperature(CameraObj,Temp)
            CameraObj.CameraDriverHndl.Temperature = Temp;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not get temperature"
                    CameraObj.lastError = "could not get temperature";
            end
        end

        
        function ExpTime=get.ExpTime(CameraObj)
            % ExpTime in seconds
            ExpTime = CameraObj.CameraDriverHndl.ExpTime;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not get exposure time"
                    CameraObj.lastError = "could not get exposure time";
            end
        end

        function set.ExpTime(CameraObj,ExpTime)
            % ExpTime in seconds
            CameraObj.CameraDriverHndl.ExpTime = ExpTime;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not set exposure time"
                    CameraObj.lastError = "could not set exposure time";
            end
        end

        
        function Gain=get.Gain(CameraObj)
            Gain = CameraObj.CameraDriverHndl.Gain;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not get gain"
                    CameraObj.lastError = "could not get gain";
            end
        end
        
        function set.Gain(CameraObj,Gain)
            % for an explanation of gain & offset vs. dynamics, see
            %  https://www.qhyccd.com/bbs/index.php?topic=6281.msg32546#msg32546
            %  https://www.qhyccd.com/bbs/index.php?topic=6309.msg32704#msg32704
            CameraObj.CameraDriverHndl.Gain = Gain;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not set gain"
                    CameraObj.lastError = "could not set gain";
            end
        end
        
        
        % ROI - assuming that this is what the SDK calls "Resolution"
        function set.ROI(CameraObj,roi)
            % resolution is [x1,y1,sizex,sizey]
            %  I highly suspect that this setting is very problematic
            %   especially in color mode.
            CameraObj.CameraDriverHndl.ROI = roi;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not set ROI"
                    CameraObj.lastError = "could not set ROI";
            end
        end

        
        function offset=get.offset(CameraObj)
            % Offset seems to be a sort of bias, black level
            offset = CameraObj.CameraDriverHndl.offset;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not get offset"
                    CameraObj.lastError = "could not get offset";
            end
        end
        
        function set.offset(CameraObj,offset)
            CameraObj.CameraDriverHndl.offset = offset;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not set offset"
                    CameraObj.lastError = "could not set offset";
            end
        end

        
        function readMode=get.ReadMode(CameraObj)
            readMode = CameraObj.CameraDriverHndl.readMode;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not get the read mode"
                    CameraObj.lastError = "could not get the read mode";
            end
        end

        function set.ReadMode(CameraObj,readMode)
            CameraObj.CameraDriverHndl.readMode = readMode;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not set the read mode"
                    CameraObj.lastError = "could not set the read mode";
            end
        end


        function set.binning(CameraObj,binning)
            % default is 1x1
            % for the QHY367, 1x1 and 2x2 seem to work; NxN with N>2 gives
            % error.
            CameraObj.CameraDriverHndl.binning = binning;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not set the binning"
                    CameraObj.lastError = "could not set the binning";
            end
        end
        
        % The SDK doesn't provide a function for getting the current
        %  binning, go figure

        function set.color(CameraObj,ColorMode)
            % default has to be bw
            CameraObj.CameraDriverHndl.binning = ColorMode;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not set the binning"
                    CameraObj.lastError = "could not set color mode";
            end
        end

        function set.bitDepth(CameraObj,BitDepth)
            % BitDepth: 8 or 16 (bit). My understanding is that this is in
            %  first place a communication setting, which however implies
            %  the scaling of the raw ADC readout. IIUC, e.g. a 14bit ADC
            %  readout is upshifted to full 16 bit range in 16bit mode.
            % Constrain BitDepth to 8|16, the functions wouldn't give any
            %  error anyway for different values.
            % default has to be bw
            CameraObj.CameraDriverHndl.binning = BitDepth;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not set bit depth"
                    CameraObj.lastError = "could not set bit depth";
            end    
        end

        function bitDepth=get.bitDepth(CameraObj)
            bitDepth = CameraObj.CameraDriverHndl.bitDepth;
            switch CameraObj.CameraDriverHndl.lastError
                case "could not get bit depth"
                    CameraObj.lastError = "could not get bit depth";
            end
        end

    end
    
end