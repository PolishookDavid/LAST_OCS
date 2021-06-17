% mount control handle class
% Package: +obs/@mount
% Description: operate mount drivers.
%              Currently can work with Xerxes, iOptron and Celestron mounts
% Input  : none.
% Output : A mount class
%     By :
% Example:  M = obs.mount;   % default is 'Xerxes'
%           M = obs.mount('Xerxes');
%           % connect without configuration file, will require setting the
%           ObsLon, ObsLat
%           M.connect; 
%           M.ObsLon = 35; M.ObsLat=32;
%           M.goto(0,0,'ha')
%           
%           % connect with configuration file _1_1
%           M.connect([1 1])
%           M.goto(10,10,'ha')
%
%           M.stopMotors % dis-engage motors (mount in neutral)
%
% Settings parameters options:
%     M.connect;      % Connect to the driver and mount controller
%     M.goto(10,50)   % Send telescope to RA & Dec in degrees
%     M.goto(10,50,'InCooType','a');  % Send telescope to Az & Alt in degrees
%     M.goto('10:00:00','+50:00:00'); % Send telescope to RA & Dec in hours and degrees
%     M.goto('M31');                  % Send to known target in SIMBAD catalog
%     M.goto('9804;',[],'NameServer','jpl'); % Send to known moving target in JPL catalog
%     M.abort;                        % Abort telescope motion
%     M.track;                        % Operate tracking in sidereal rate
%     M.track(val);                   % Operate tracking in rate val in units of degrees/sec
%     M.home;                         % Send telescope home position.
%     M.park;                         % Send telescope to park position.
%     M.park(false);                  % Release telescope from park position.
%     M.waitFinish;                   % Wait for mount to complete slewing
%
%     M.Handle;             % Direct excess to the driver object
%
% Author: Enrico Segre, Jun 2021
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

classdef mount < obs.LAST_Handle

    properties (Dependent)
        % mount direction and motion
        RA(1,1) double     = NaN      % Deg
        Dec(1,1) double    = NaN      % Deg
        HA(1,1) double     = NaN      % Deg
        Az(1,1) double     = NaN      % Deg
        Alt(1,1) double    = NaN      % Deg
        TrackingSpeed(1,2) double = [NaN NaN]  % Deg/s
    end

    properties (GetAccess=public, SetAccess=private)
        % Mount configuration
        Status  char       = 'unknown';   % 'unknown' | 'idle' | 'slewing' | 'tracking'
        IsEastOfPier       = NaN;
    end
    
    properties(Hidden)
        Handle   obs.LAST_Handle     % Mount driver handle
        %LastRC    = '';
        LogFile            = LogFile;
        LogFileDir char    = '';
        IsConnected = false; % Connection status between class to camera
        %IsCounterWeightDown=true; % Test that this works as expected
    end
    
    % Mount ID
    properties(Hidden)
        MountName char          = '';         % The mount serial ID - e.g., 'RAD21drive-932187746_DecD21Dual-13182557'
        MountModel char         = 'unknown';  % Mount model - e.g., 'Xerxes-20'
        MountClass char         = 'unknown';  % class of the mount driver - e.g., 'inst.XerxesMount'
        MountNumber(1,1) double = NaN;
        ObsLon(1,1) double      = NaN;
        ObsLat(1,1) double      = NaN;
        ObsHeight(1,1) double   = NaN;
    end
    
    % safety 
    properties(Hidden)
        MinAlt(1,1) double     = 15;   % deg
        AzAltLimit cell      = {0, 15; 90, 15; 180, 15; 270, 15; 360, 15}; % deg (cell because of yml conversion)
        HALimit double         = 120;  % deg
        ParkPos(1,2) double    = [0 0];   % HA, Dec [deg]
    end
    
    % communication
    properties(Hidden)
        MountIP            % IP / used for iOptron        
    end
        
    % utils
    properties(Hidden)
        SlewingTimer;        
        TimeFromGPS logical     = false;        
    end
    
    properties(Hidden,Constant)
        SiderealRate = 360/86164.0905; %sidereal tracking rate, degrees/sec
    end
    
        
%         IPaddress = '';
%         Port = '';
%         SerialResource % the serial object corresponding to Port
% 
%         % Mount and telescopes names and models
%         MountUniqueName = '';
%         MountGeoName = '';
%         TelescopeEastUniqueName = '';
%         TelescopeWestUniqueName = '';
%         
%         MinAzAltMap = NaN;
%         MinAltPrev = NaN;
%         MeridianFlip=true; % if false, stop at the meridian limit
%         MeridianLimit=92; % Test that this works as expected, no idea what happens
%         
%         DistortionFile = '';
% 
%         MountPos=[NaN,NaN,NaN];
%         MountCoo = struct('ObsLon',NaN,'ObsLat',NaN,'ObsHeight',NaN);
%         MountUTC
%         ParkPos = [NaN,NaN]; % park pos in [Az,Alt] (negative Alt is impossible)
%     
        
    % constructor and destructor
    methods
        function MountObj=mount(id)
            % mount class constructor
            % Package: +obs/@mount
            % Input  : .Id to set,
            if exist('id','var')
                MountObj.Id=id;
            end
            % load configuration
            MountObj.loadConfig(MountObj.configFileName('create'))            
        end
        
        function delete(MountObj)
            % delete mount object and related sub objects (if they were
            % defined)
            try
                MountObj.Handle.delete;
                % Delete the timer
                delete(MountObj.SlewingTimer);
            catch
            end
        end
        
    end
    
        
    % setters and getters
    methods
        function RA=get.RA(MountObj)
            % getter for RA [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            try
                RA = MountObj.Handle.RA;
            catch
                RA = NaN;
                MountObj.reportError('Mount object cannot report RA');
            end
        end
        
        function set.RA(MountObj,RA)
            % setter for RA [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            try
                MountObj.Handle.RA = RA;
            catch
                MountObj.reportError('Mount object cannot set RA');
            end
        end
        
        function Dec=get.Dec(MountObj)
            % getter for Dec [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            try
                Dec = MountObj.Handle.Dec;
            catch
                Dec = NaN;
                MountObj.reportError('Mount object cannot report Dec');
            end
        end
        
        function set.Dec(MountObj,Dec)
            % setter for Dec [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            try                % a known mount object
                MountObj.Handle.Dec = Dec;
            catch
                MountObj.reportError('Mount object cannot set Dec');
            end
        end
       
        function HA=get.HA(MountObj)
            % getter for HA [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron            
            try
                HA = MountObj.Handle.HA;
            catch
                HA = NaN;
                MountObj.reportError('Mount object cannot report HA');
            end
        end
        
        function set.HA(MountObj,HA)
            % setter for HA [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            try
                MountObj.Handle.HA = HA;
            catch
                MountObj.reportError('Mount object cannot set HA');
            end
        end
        
        
        function Az=get.Az(MountObj)
            % getter for Az [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            try
                Az = MountObj.Handle.Az;
            catch
                Az = NaN;
                MountObj.reportError('Mount object cannot report Az');
            end
        end
        
        function set.Az(MountObj,Az)
            % setter for Az [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron            
            try
                MountObj.Handle.Az = Az;
            catch
                MountObj.reportError('Mount object cannot set Az');
            end
        end
        
        function Alt=get.Alt(MountObj)
            % getter for Alt [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            try
                Alt = MountObj.Handle.Alt;
            catch
                Alt = NaN;
                MountObj.reportError('Mount object cannot report Alt');                
            end
        end
        
        function set.Alt(MountObj,Alt)
            % setter for Alt [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            try
                MountObj.Handle.Alt = Alt;
            catch
                MountObj.reportError('Mount object cannot set Alt');
            end
        end
        
        function TrackingSpeed=get.TrackingSpeed(MountObj)
            % getter for Tracking speed [Deg/s] in [HA, Dec]           
            try
                TrackingSpeed = MountObj.Handle.TrackingSpeed;
            catch
                TrackingSpeed = [NaN NaN];
                % write error to logFile
                MountObj.reportError('Mount object cannot report TrackingSpeed');
            end
        end
        
        function set.TrackingSpeed(MountObj,TrackingSpeed)
            % setter for Tracking speed - THIS DOES NOT ACTIVATE TRACKING
            % Use M.track to activate tracking
            % Input  : - Mount object.
            %          - [HA, Dec] speed, if scalar, than Dec speed is set
            %            to zero.
            %            String: 'sidereal' | 'sid' | 'lunar'
            
            MaxSpeed = 1;
            
            if ischar(TrackingSpeed)
                switch lower(TrackingSpeed)
                    case {'sidereal','sid'}
                        TrackingSpeed = [MountObj.SiderealRate, 0];
                    case 'lunar'
                        TrackingSpeed = [MountObj.SiderealRate - 360./27.3./86400, 0];
                    otherwise
                        MountObj.reportError('Unknown TrackingSpeed string option');
                end
            else
                if numel(TrackingSpeed)==1
                    TrackingSpeed = [TrackingSpeed, 0];
                elseif numel(TrackingSpeed)==2
                    % ok.
                else
                    MountObj.reportError('TrackingSpeed must be a scalar, two element vector or string');
                end
            end            
            if max(abs(TrackingSpeed))>MaxSpeed
                MountObj.reportError('TrackingSpeed is above limit of %f deg/s',MaxSpeed);
            end

            try
                MountObj.Handle.TrackingSpeed = TrackingSpeed;
                %MountObj.Handle.track(TrackingSpeed);  % activate tracking
            catch
                MountObj.reportError('Mount object cannot set TrackingSpeed')
            end
                
        end
        
        function Status=get.Status(MountObj)
            % getter for mount status
            try
                Status = MountObj.Handle.Status;
            catch
                Status = 'unknown';
                MountObj.reportError('Mount object cannot report Status')
            end
        end
    end

    
end
