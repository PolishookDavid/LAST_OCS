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
% Author: David Polishook, Mar 2020
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
        Handle             = [];     % Mound driver handle
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
        MountType char          = 'unknown';  % MountType - e.g., 'Xerxes'
        MountNumber(1,1) double = NaN;
        NodeNumber(1,1) double  = NaN;
        ObsLon(1,1) double      = NaN;
        ObsLat(1,1) double      = NaN;
        ObsHeight(1,1) double   = NaN;
    end
    
    % safety 
    properties(Hidden)
        MinAlt(1,1) double     = 15;   % deg
        AzAltLimit double      = [[0, 15];[90, 15];[180, 15];[270, 15];[360, 15]]; % deg
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
    
    
    % static methods
    methods (Static)
        % THESE REEK. why there should be tests inide this class
        %  in order to find if the object is of its class itself?
        %  And if this is an abstraction class, what for should be checking
        %  that the driver is really a driver object?
        % I suspect that these come from a misuse of configuration layers,
        %  or some other design mistake
        function Ans=ismountObj(Obj)
            % Return true if mount abstraction object.
            % Example: Ans = obs.mount.ismountObj(M)           
            Ans = isa(Obj,'obs.mount');
        end
        
        function Ans=ismountDriver(Obj)
            % Return true if mount driver object.
            % Example: Ans = obs.mount.ismountDriver(M)
            Ans = isa(Obj,'inst.XerxesMount') || isa(Obj,'inst.iOptronCEM120');
        end
        
    end
    
    
    % setters and getters
    methods
        function RA=get.RA(MountObj)
            % getter for RA [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if isempty(MountObj.Handle)
                RA = NaN;
                % write error to logFile
                MountObj.LogFile.writeLog('MountObj.Handle is empty');
            else
                if obs.mount.ismountDriver(MountObj.Handle)
                    % a known mount object
                    RA = MountObj.Handle.RA;
                else
                    RA = NaN;
                    MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                end
            end
        end
        
        function set.RA(MountObj,RA)
            % setter for RA [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if obs.mount.ismountDriver(MountObj.Handle)
                % a known mount object
                MountObj.Handle.RA = RA;
            else
                MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                error('MountObj.Handle is not of mountDriver class');
            end
        end
        
        function Dec=get.Dec(MountObj)
            % getter for Dec [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if isempty(MountObj.Handle)
                Dec = NaN;
                % write error to logFile
                MountObj.LogFile.writeLog('MountObj.Handle is empty');
            else
                if obs.mount.ismountDriver(MountObj.Handle)
                    % a known mount object
                    Dec = MountObj.Handle.Dec;
                else
                    Dec = NaN;
                    MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                end
            end
        end
        
        function set.Dec(MountObj,Dec)
            % setter for Dec [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if obs.mount.ismountDriver(MountObj.Handle)
                % a known mount object
                MountObj.Handle.Dec = Dec;
            else
                MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                error('MountObj.Handle is not of mountDriver class');
            end
        end
       
        function HA=get.HA(MountObj)
            % getter for HA [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if isempty(MountObj.Handle)
                HA = NaN;
                % write error to logFile
                MountObj.LogFile.writeLog('MountObj.Handle is empty');
            else
                if obs.mount.ismountDriver(MountObj.Handle)
                    % a known mount object
                    HA = MountObj.Handle.HA;
                else
                    HA = NaN;
                    MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                end
            end
        end
        
        function set.HA(MountObj,HA)
            % setter for HA [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if obs.mount.ismountDriver(MountObj.Handle)
                % a known mount object
                MountObj.Handle.HA = HA;
            else
                MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                error('MountObj.Handle is not of mountDriver class');
            end
        end
        
        
        function Az=get.Az(MountObj)
            % getter for Az [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if isempty(MountObj.Handle)
                Az = NaN;
                % write error to logFile
                MountObj.LogFile.writeLog('MountObj.Handle is empty');
            else
                if obs.mount.ismountDriver(MountObj.Handle)
                    % a known mount object
                    Az = MountObj.Handle.Az;
                else
                    Az = NaN;
                    MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                end
            end
        end
        
        function set.Az(MountObj,Az)
            % setter for Az [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if obs.mount.ismountDriver(MountObj.Handle)
                % a known mount object
                MountObj.Handle.Az = Az;
            else
                MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                error('MountObj.Handle is not of mountDriver class');
            end
        end
        
        function Alt=get.Alt(MountObj)
            % getter for Alt [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if isempty(MountObj.Handle)
                Alt = NaN;
                % write error to logFile
                MountObj.LogFile.writeLog('MountObj.Handle is empty');
                
            else
                if obs.mount.ismountDriver(MountObj.Handle)
                    % a known mount object
                    Alt = MountObj.Handle.Alt;
                    
                else
                    Alt = NaN;
                    MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                end
            end
        end
        
        function set.Alt(MountObj,Alt)
            % setter for Alt [deg]
            % Equinox is date for Xerxes, and J2000 for iOptron
            
            if obs.mount.ismountDriver(MountObj.Handle)
                % a known mount object
                MountObj.Handle.Alt = Alt;
            else
                MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                error('MountObj.Handle is not of mountDriver class');
            end
        end
        
        function TrackingSpeed=get.TrackingSpeed(MountObj)
            % getter for Tracking speed [Deg/s] in [HA, Dec]
           
            if isempty(MountObj.Handle)
                TrackingSpeed = [NaN NaN];
                % write error to logFile
                MountObj.LogFile.writeLog('MountObj.Handle is empty');
            else
                if obs.mount.ismountDriver(MountObj.Handle)
                    % a known mount object
                    TrackingSpeed = MountObj.Handle.TrackingSpeed;
                else
                    TrackingSpeed = NaN;
                    MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                end
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
                        error('Unknwon TrackingSpeed string option');
                end
            else
                if numel(TrackingSpeed)==1
                    TrackingSpeed = [TrackingSpeed, 0];
                elseif numel(TrackingSpeed)==2
                    % ok.
                else
                    error('TrackingSpeed must be a scalar, two element vector or string');
                end
            end
            
            if max(abs(TrackingSpeed))>MaxSpeed
                error('TrackingSpeed is above limit of %f deg/s',MaxSpeed);
            end
            
             if obs.mount.ismountDriver(MountObj.Handle)
                % a known mount object
                MountObj.Handle.TrackingSpeed = TrackingSpeed;
                %MountObj.Handle.track(TrackingSpeed);  % activate tracking
            else
                MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                error('MountObj.Handle is not of mountDriver class');
            end
                
        end
        
        function Status=get.Status(MountObj)
            % getter for mount status
           
            if obs.mount.ismountDriver(MountObj.Handle)
                Status = MountObj.Handle.Status;
            else
                MountObj.LogFile.writeLog('MountObj.Handle is not of mountDriver class');
                error('MountObj.Handle is not of mountDriver class');
            end
        end
        
    end

    
end
