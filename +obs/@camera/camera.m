% Abstraction class for a single camera
% Package: +obs.camera
% Description: This abstraction class support and opperate the driver
%              classes for either the QHY or ZWO detectors.
% Some basic examples:
%   C = obs.camera('QHY');  % create an empty camera object for a QHY device
%   C.connect               % connect the camera
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
    end
    
    properties(Hidden, GetAccess = public, SetAccess = private)
        % Start time and end time of the last integration.
        TimeStart double     = [];
        TimeEnd double       = [];
        %TimeStartPrev double = [];  % This is the start time as obtained from the camera immediately after the camera return to idle state.
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
        Handle;           % Handle to camera driver class        
        ReadoutTimer;     % A timer object to operate after exposure start, to wait until the image is ready.
        %ImageFormat = 'fits';    % The format of the written image
        %MaxExpTime = 1800;  % Maximum exposure time in seconds
        % The serial number of the last image - not implemented anymore
        %LastImageSerialNum = 0;
        % A flag marking if to print software printouts or not        
    end
    
    
    % constructor and destructor
    methods
                
        function CameraObj=camera(id)
            % Camera object constructor
            if exist('id','var')
                CameraObj.Id=id;
            end
            % load configuration
            CameraObj.loadConfig(CameraObj.configFileName('create'))
        end
       
        function delete(CameraObj)
            % Delete properly driver object + set IsConnected to false
            if ~isempty(CameraObj.Handle)
                CameraObj.Handle.delete;
                CameraObj.IsConnected = false;
            end
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
            Q.Verbose   = false;                % optional if you want to see less blabber
            AllCamNames = Q.allQHYCameraNames;

            if nargout>1 && ~isempty(CameraName)
                %CameraNumSDK = find(strcmp(AllCamNames,'QHY367C-e2f51243929ddaaf5'));
                CameraNumSDK = find(strcmp(AllCamNames,CameraName));
            else
                CameraNumSDK = [];
            end
        end
       
        
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
                    ErrorStr = 'Cannot get ExpTime because camera may be not connected';
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
                    ErrorStr = 'Cannot set ExpTime because camera may be not connected';
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
                    ErrorStr = 'Cannot get Temperature because camera may be not connected';
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
                    ErrorStr = 'Cannot set Temperature because camera may be not connected';
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
                ErrorStr = 'Cannot get Status because camera may be not connected';
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
                    ErrorStr = 'Cannot get CoolingPower because camera may be not connected';
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
                    ErrorStr = 'Cannot get TimeStart because camera may be not connected';
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
                    ErrorStr = 'Cannot get TimeEnd because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
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
                ErrorStr = 'Cannot get LastImage because camera may be not connected';
                if Obj.Verbose
                    warning(ErrorStr);
                end
                Obj.LogFile.writeLog(ErrorStr);
            end
        end
        
        % ReadMode
        function Output=get.ReadMode(Obj)
            % getter template
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.ReadMode;
                else
                    ErrorStr = 'Cannot get ReadMode because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        function set.ReadMode(Obj,InputPar)
            % setter template
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Obj(I).Handle.ReadMode = InputPar;
                else
                    ErrorStr = 'Cannot set ReadMode because camera may be not connected';
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
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.Offset;
                else
                    ErrorStr = 'Cannot get Offset because camera may be not connected';
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
                    ErrorStr = 'Cannot set Offset because camera may be not connected';
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
            N      = numel(Obj);
            Output = nan(1,N);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Output(I) = Obj(I).Handle.Gain;
                else
                    ErrorStr = 'Cannot get Gain because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
        
        function set.Gain(Obj,InputPar)
            % setter template
            N = numel(Obj);
            for I=1:1:N
                if Obj(I).IsConnected 
                    Obj(I).Handle.Gain = InputPar;
                else
                    ErrorStr = 'Cannot set Gain because camera may be not connected';
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
                ErrorStr = 'Cannot get Binning because camera may be not connected';
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
                    ErrorStr = 'Cannot set Binning because camera may be not connected';
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
                ErrorStr = 'Cannot get CoolingPower because camera may be not connected';
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
                    ErrorStr = 'Cannot set CoolingPower because camera may be not connected';
                    if Obj(I).Verbose
                        warning(ErrorStr);
                    end
                    Obj(I).LogFile.writeLog(ErrorStr);
                end
            end
        end
                  
        
    end
    
end