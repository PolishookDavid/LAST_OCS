% mount control handle class
% Package: +obs/@mount
% Description: operate mount drivers.
%              Intended for working with Xerxes, iOptron and Celestron mounts
% Input  : none.
% Output : A mount class
%     By :
% Example:  M = obs.mount;   % default is 'Xerxes'
%           M = obs.mount('Xerxes');
%           % connect without configuration file, will require setting the
%           ObsLon, ObsLat
%           M.connect; 
%           M.ObsLon = 35; M.ObsLat=32;
%           M.goToTarget(0,0,'ha')
%           
%           % connect with configuration file _1_1
%           M.connect([1 1])
%           M.goToTarget(10,10,'ha')
%
%           M.stopMotors % dis-engage motors (mount in neutral)
%
% Settings parameters options:
%     M.connect;      % Connect to the driver and mount controller
%     M.goToTarget(10,50)   % Send telescope to RA & Dec in degrees
%     M.goToTarget(10,50,'InCooType','a');  % Send telescope to Az & Alt in degrees
%     M.goToTarget('10:00:00','+50:00:00'); % Send telescope to RA & Dec in hours and degrees
%     M.goToTarget('M31');                  % Send to known target in SIMBAD catalog
%     M.goToTarget('9804;',[],'NameServer','jpl'); % Send to known moving target in JPL catalog
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

    properties (Transient)
        % TrackingSpeed(1,2) double = [NaN NaN]  % Deg/s %% support 'sidereal', 'lunar'?
    end
    
    properties(Hidden)
        Handle   obs.LAST_Handle     % Mount driver handle
        %LastRC    = '';
        LogFile            = LogFile;
        LogFileDir char    = '';
        IsConnected = false; % Connection status between class to camera (??)
        %IsCounterWeightDown=true; % Test that this works as expected
    end
    
    % Mount ID
    properties(Hidden=true)
        ObsLon(1,1) double      = NaN;
        ObsLat(1,1) double      = NaN;
        ObsHeight(1,1) double   = NaN;
    end
    
    % safety 
    properties(Hidden)
        AzAltLimit cell      = {0, 15; 90, 15; 180, 15; 270, 15; 360, 15}; % deg (cell because of yml conversion)
        HALimit double         = 120;  % deg
    end
    
    % communication
    properties(Hidden)
        PhysicalPort            % usb-serial bridge address / IP (for iOptron)        
    end
        
    % utils
    properties(Hidden)
        SlewingTimer;        
        TimeFromGPS logical     = false;        
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
            % eval because of
            % https://github.com/EranOfek/AstroPack/issues/6#issuecomment-861471636
            % pass geographical coordinates to the driver
            MountObj.MountPos=[MountObj.ObsLat,MountObj.ObsLon,MountObj.ObsHeight];
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
%         function set.TrackingSpeed(MountObj,TrackingSpeed)
%             % setter for Tracking speed - THIS DOES NOT ACTIVATE TRACKING
%             % Use M.track to activate tracking
%             % Input  : - Mount object.
%             %          - [HA, Dec] speed, if scalar, than Dec speed is set
%             %            to zero.
%             %            String: 'sidereal' | 'sid' | 'lunar'
%             
%             MaxSpeed = 1;
%             
%             if ischar(TrackingSpeed)
%                 switch lower(TrackingSpeed)
%                     case {'sidereal','sid'}
%                         TrackingSpeed = [MountObj.SiderealRate, 0];
%                     case 'lunar'
%                         TrackingSpeed = [MountObj.SiderealRate - 360./27.3./86400, 0];
%                     otherwise
%                         MountObj.reportError('Unknown TrackingSpeed string option');
%                 end
%             else
%                 if numel(TrackingSpeed)==1
%                     TrackingSpeed = [TrackingSpeed, 0];
%                 elseif numel(TrackingSpeed)==2
%                     % ok.
%                 else
%                     MountObj.reportError('TrackingSpeed must be a scalar, two element vector or string');
%                 end
%             end            
%             if max(abs(TrackingSpeed))>MaxSpeed
%                 MountObj.reportError('TrackingSpeed is above limit of %f deg/s',MaxSpeed);
%             end
% 
%             try
%                 MountObj.Handle.TrackingSpeed = TrackingSpeed;
%                 %MountObj.Handle.track(TrackingSpeed);  % activate tracking
%             catch
%                 MountObj.reportError('Mount object cannot set TrackingSpeed')
%             end
%                 
%         end

    % these are merely name translations from properties of the child class
        function lon=get.ObsLon(M)
            lon=M.MountPos(2);
        end

        function lat=get.ObsLat(M)
            lat=M.MountPos(1);
        end

        function height=get.ObsHeight(M)
            height=M.MountPos(3);
        end
        
    end

    
end
