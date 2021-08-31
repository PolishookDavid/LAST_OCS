% Mount control superclass
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

    properties (GetAccess=public, SetAccess=private)
        LST double % Local Sidereal Time (LST) in [deg] (fraction of day)
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
        AzAltLimit double      = [0, 15; 90, 15; 180, 15; 270, 15; 360, 15]; % deg
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
            MountObj.loadConfig(MountObj.configFileName('createsuper'))
            % pass geographical coordinates to the driver
            MountObj.MountPos=[MountObj.ObsLat,MountObj.ObsLon,MountObj.ObsHeight];
            
            % Open the logFile (what do we want to do here? Open a different log
            %  file for each device, or one for the whole unitCS?)
            if isempty(MountObj.LogFile)
                %         % create a logFile, but with empty TemplateFileName so no
                %         % writing is performed
                %         MountObj.LogFile = logFile;
                %         MountObj.LogFile.FileNameTemplate = [];
                %         % .Dir missing in Astropack's LogFile
                %         MountObj.LogFile.LogPath = '~';
            else
                %         MountObj.LogFileDir = ConfigStruct.LogFileDir;
                %         % .logOwner missing in Astropack's LogFile
                %         % MountObj.LogFile.logOwner = sprintf('mount_%d_%d',MountAddress);
                %         % .Dir missing in Astropack's LogFile
                %         MountObj.LogFile.LogPath = ConfigStruct.LogFileDir;
            end
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
        function LST=get.LST(M)
            % Get the Local Sidereal Time (LST) in [deg] (fraction of day)

            RAD = 180./pi;
            % Get JD from the computer
            JD = celestial.time.julday;
            LST = celestial.time.lst(JD,M.ObsLon./RAD);  % fraction of day
            LST = LST.*360;
        end

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
