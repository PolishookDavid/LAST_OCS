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

classdef mount <obs.LAST_Handle

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
        LogFile            = logFile;
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
        MountIP            % IP / used for iOptron
                
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
%         MountType = '';
%         MountModel = '';
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
        
    % constructor and delete
    methods
        function MountObj=mount(MountType)  
            % mount class constructor
            % Package: +obs/@mount
            % Input  : - Mount type ['xerxes'] | 'ioptron'
            % Example: M=obs.mount('xerxes')
            
            if nargin<1
                MountType = 'Xerxes';
            end
            MountObj.MountType = MountType;
            

            % Open a driver object for the mount
            switch lower(MountObj.MountType)
                case 'xerxes'
                    MountObj.Handle=inst.XerxesMount();
                case 'ioptron'
                    MountObj.Handle=inst.iOptronCEM120();
                otherwise
                    error('Unknown MountType');
            end
            
        end
        
        function delete(MountObj)
            % delete mount object and related sub objects
            MountObj.Handle.delete;
            % Delete the timer
            delete(MountObj.SlewingTimer);
        end
        
    end
    
    % connect, disconnect, restart, abort
    methods 

        
        function connect(MountObj,MountAddress,MountType)
            % Connect a mount abstraction object
            % Description: Connect the mount object to the actual mount,
            %              open a logFile object, and read the
            %              configuration files related to the mount.
            % Input  : - Mount object
            %          - This can be:
            %            1. A mount address which is a vector of
            %               [NodeNumber, MountNumber]
            %            2. A mount configuration file name (string).
            %            3. Empty [default]. In this case, some default
            %               values will be used.
            %          - MountType : 'xerxes' | 'ioptron'.
            %            If not given will attempt to read from Config
            % Example: M.connect([],'xerxes')
            
            ConfigBaseName  = 'config.mount';
            PhysicalKeyName = 'MountName';
            ListProp        = {'NodeNumber',...
                               'MountType',...
                               'MountModel',...
                               'MountName',...
                               'MountNumber',...
                               'ObsLon',...
                               'ObsLat',...
                               'ObsHeight',...
                               'LogFileDir'};

            
            if nargin<2
                MountAddress = [];
            end
            
            if nargin==3
                MountObj.MountType = MountType;
            end
            
            if ischar(MountAddress)
                MountAddress = [NaN NaN];
            else
                if numel(MountAddress)~=2
                    MountAddress = [NaN NaN];
                end
            end
            
            if any(isnan(MountAddress))
                ConfigStruct   = [];
                ConfigLogical  = [];
                ConfigPhysical = [];
                
            else
                %[ConfigLogical,ConfigPhysical] = MountObj.readConfig(MountAddress);
%                 [ConfigStruct,ConfigLogical,ConfigPhysical,ConfigFileNameLogical,ConfigFileNamePhysical]=readConfig(MountObj,...
%                                     MountAddress,...
%                                     ConfigBaseName,PhysicalKeyName);
                [ConfigStruct] = getConfigStruct(MountObj,...
                                    MountAddress,...
                                    ConfigBaseName,PhysicalKeyName);                
                MountObj.ConfigStruct = ConfigStruct;               
                MountObj = updatePropFromConfig(MountObj,ListProp,MountObj.ConfigStruct);
            end
            
            % Open the logFile
            if isempty(MountObj.LogFile) || isempty(ConfigStruct)
                % create a logFile, but with empty TemplateFileName so no
                % writing is performed
                MountObj.LogFile = logFile;
                MountObj.LogFile.FileNameTemplate = [];
                MountObj.LogFile.Dir = '~';
            else
                MountObj.LogFileDir = ConfigStruct.LogFileDir;
                MountObj.LogFile.logOwner = sprintf('mount_%d_%d',MountAddress);
                MountObj.LogFile.Dir = ConfigStruct.LogFileDir;
            end
            
            % write logFile
            MountObj.LogFile.writeLog(sprintf('Connecting to mount address: %d %d %d / Name: %s',MountAddress,MountObj.MountName));
            
            
            switch lower(MountObj.MountType)
                case 'xerxes'
                    if Util.struct.isfield_notempty(MountObj.ConfigStruct,'PhysicalPort')
                        PhysicalPort = MountObj.ConfigStruct.PhysicalPort;
                        MountPort    = idpath_to_port(PhysicalPort);
                    else
                        MountPort = [];
                    end
                    
                case 'ioptron'
                    % TODO: This need to be in the Config file
                    MountObj.MountIP = '192.168.11.254';
                    MountPort = MountObj.MountIP;
                otherwise
                    error('Unknown MountType option - provide as input argument to connect');
            end
                    
            Success = MountObj.Handle.connect(MountPort);
            MountObj.IsConnected = Success;
    
            if Success
                MountObj.LogFile.writeLog('Mount is connected successfully')
                
                %MountObj.MountModel = MountObj.Handle.MountModel;
        
                % Mount location coordinates and UTC
                if (MountObj.TimeFromGPS)
                    % Take from GPS
                    if isfield(MountObj.Handle.FullStatus,'Lon')
                        MountObj.ObsLon = MountObj.Handle.FullStatus.Lon;
                    else
                        MountObj.LogFile.writeLog('Lon is not available');
                        error('Lon is not available');
                    end
                    if isfield(MountObj.Handle.FullStatus,'Lat')
                        MountObj.ObsLat = MountObj.Handle.FullStatus.Lat;
                    else
                        MountObj.LogFile.writeLog('Lat is not available');
                        error('Lat is not available');
                    end
                else
                    
                    % Take coordinates from Config - already taken 
%                     if isfield(ConfigLogical,'ObsLon')
%                         MountObj.ObsLon = ConfigLogical.ObsLon;
%                     else
%                         MountObj.LogFile.writeLog('ObsLon is not available');
%                         warning('ObsLon is not available');
%                     end
%                     if isfield(ConfigLogical,'ObsLat')
%                         MountObj.ObsLat = ConfigLogical.ObsLat;
%                     else
%                         MountObj.LogFile.writeLog('ObsLat is not available');
%                         warning('ObsLat is not available');
%                     end
%                     if isfield(ConfigLogical,'ObsHeight')
%                         MountObj.ObsHeight = ConfigLogical.ObsHeight;
%                     else
%                         MountObj.LogFile.writeLog('ObsHeight is not available');
%                         warning('ObsHeight is not available');
%                     end
                    
                    %MountObj.MountPos = [MountObj.MountCoo.ObsLon MountObj.MountCoo.ObsLat MountObj.MountCoo.ObsHeight];
                    % Update UTC clock on mount for iOptron
                    %if(strcmp(MountObj.MountType, 'iOptron'))
                    %    MountObj.Handle.MountUTC = 'dummy';
                    %end
                end

            else
                MountObj.LogFile.writeLog('Mount was not connected successfully')
                MountObj.LastError = sprintf("Mount %s is disconnected", num2str(ConfigMount.MountNumber));
            end
            
            
            
            
            
        end
        
        function Success=disconnect(MountObj)
            % disconnect a mount object including the driver
            
            if MountObj.IsConnected
                MountObj.LogFile.writeLog('call mount.disconnect')
                 try
                    MountObj.Handle.disconnect;
                    MountObj.IsConnected = false;
                    Success = true;
                 catch
                    MountObj.LogFile.writeLog('mount.disconnect failed')
                    MountObj.LastError = 'mount.disconnect failed';
                 end
            else
                MountObj.LogFile.writeLog('can not disconnect mount because IsConnected=false')
                MountObj.LastError = 'can not disconnect mount because IsConnected=false';
            end
            if ~isempty(MountObj.LogFile)
                %MountObj.LogFile.delete;
                %MountObj.LogFile = [];
            end
            
        end   
        
        function abort(MountObj)
            % emergency stop
               if MountObj.IsConnected

                  MountObj.LogFile.writeLog('Abort mount slewing')

                  % Stop the mount motion through the driver object
                  MountObj.Handle.abort;

                  % Delete the slewing timer
                  delete(MountObj.SlewingTimer);
               end
            end

        function Obj=restart(Obj)
            % restart the xerxes mount handle

            Obj.Handle.disconnect
            Obj.Handle.delete

            X = inst.XerxesMount;
            X.connect;
            Obj.Handle = X;
        end
        
        function restoreEncoderPositionToDefault(MountObj)
            % Restore encoder  HA/Dec Zero Position Ticks to Default value
            % The default value is stored in the physical configuration
            % file
            
            if obs.mount.ismountDriver(MountObj.Handle)
                HAZeroPositionTicks  = MountObj.ConfigStruct.ConfigPhysical.DefaultHAZeroPositionTicks;
                DecZeroPositionTicks = MountObj.ConfigStruct.ConfigPhysical.DefaultDecZeroPositionTicks;
                MountObj.Handle.HAZeroPositionTicks = HAZeroPositionTicks;
                MountObj.Handle.DecZeroPositionTicks = DecZeroPositionTicks;
                % update config file
                MountObj.updateConfiguration(MountObj.Config,'HAZeroPositionTicks',sprintf('%9d',HAZeroPositionTicks),'ticks');
                MountObj.updateConfiguration(MountObj.Config,'DecZeroPositionTicks',sprintf('%9d',DecZeroPositionTicks),'ticks');

            else
                error('Mount must be connected for this operation');
            end
            
        end
        
    end
    
    
    % static methods
    methods (Static)
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
            % setter for Tracking speed - THIS DOESNOT ACTIVATE TRACKING
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
                elseif numel(TrackingSpeed==2)
                    % ok
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

    % motion and position methods
    methods
        function Flag=stopMotors(MountObj)
            % stop mount motors using the Handle.reset command
            
            MountObj.Handle.reset;
            switch lower(MountObj.Status)
                case 'disabled'
                    Flag = true;
                otherwise
                    Flag = false;
            end
            MountObj.LogFile.writeLog(sprintf('Mount motors stoped - sucess: %d',Flag));
            
        end
        
        function [Flag,RA,Dec,Aux]=goto(MountObj, Long, Lat, varargin)
            % Send mount to coordinates/name and start tracking
            % Package: @mount
            % Description: Send mount to a given coordinates in some coordinate system
            %              or equinox, or an object name; convert it to euatorial coordinates
            %              that includes the atmospheric refraction correction and optional
            %              telescope distortion model (T-point model).
            % Input  : - Longitude in some coordinate system, or object name.
            %            Longitude can be either sexagesimal coordinates or numeric
            %            calue in degress (or radians if InputUnits='rad').
            %            Object name is converted to coordinates using either SIMBAD,
            %            NED or JPL horizons.
            %          - Like the first input argument, but for the latitude.
            %            If empty, or not provided, than the first argument is assumed
            %            to be an object name.
            %          * Arbitrary number of pairs of arguments: ...,keyword,value,...
            %            where keyword are one of the followings:
            %            'InCooType'  - Input coordinates frame:
            %                           'a' - Az. Alt.
            %                           'g' - Galactic.
            %                           'e' - Ecliptic
            %                           - A string start with J (e.g., 'J2000.0').
            %                           Equatorial coordinates with mean equinox of
            %                           date, where the year is in Julian years.
            %                           -  A string start with t (e.g., 't2020.5').
            %                           Equatorial coordinates with true equinox of
            %                           date.
            %                           Default is 'J2000.0'
            %            'NameServer' - ['simbad'] | 'ned' | 'jpl'.
            %            'DistFun'    - Distortion function handle.
            %                           The function is of the form:
            %                           [DistHA,DistDec]=@Fun(HA,Dec), where all the
            %                           input and output are in degrees.
            %                           Default is empty. If not given return [0,0].
            %            'InputUnits' - Default is 'deg'.
            %            'OutputUnits'- Default is 'deg'
            %            'Temp'       - Default is 15 C.
            %            'Wave'       - Default is 5500 Ang.
            %            'PressureHg' - Default is 760 mm Hg.
            % Output : - Flag 0 if illegal input coordinates, 1 if ok.
            %          - Apparent R.A.
            %          - Apparent Dec.
            %          - A structure containing the intermidiate values.
            % License: GNU general public license version 3
            %     By : Eran Ofek                    Feb 2020
            % Example: [DistRA,DistDec,Aux]=mount.goto(10,50)
            %          mount.goto(10,50,'InCooType','a')
            %          mount.goto('10:00:00','+50:00:00');
            %          mount.goto('M31');
            %          mount.goto('9804;',[],'NameServer','jpl')
            %--------------------------------------------------------------------------

            RAD = 180./pi;

            if nargin<3
                Lat = [];
            end


            JD = celestial.time.julday;

            Flag = false;

            if MountObj.IsConnected && obs.mount.ismountDriver(MountObj.Handle)

                switch lower(MountObj.Status)
                    case 'park'
                        
                        MountObj.LogFile.writeLog('Error: Attempt to slew telescope while parking');
                        error('Can not slew telescope while parking');
                    otherwise
               
                        % Convert input into RA/Dec [input deg, output deg]
                        switch lower(MountObj.MountType)
                            case 'xerxes'
                                % output is equinox of date
                                OutputCooType = sprintf('J%8.3f',convert.time(JD,'JD','J'));
                            case 'ioptron'
                                % output is J2000
                                OutputCooType = 'J2000';
                            otherwise
                                MountObj.LogFile.writeLog('Error: Unknown MountModel option');
                                error('Unknown MountModel option');
                        end
                        
                        [RA, Dec, Aux] = celestial.coo.convert2equatorial(Long, Lat, varargin{:},'OutCooType',OutputCooType);

                        if isnan(RA) || isnan(Dec)
                            MountObj.LogFile.writeLog('Error: RA or Dec are NaN');
                            error('RA or Dec are NaN');
                        end
                        
                        % validate coordinates
                        % note that input is in [rad]

                        if isnan(MountObj.ObsLon) || isnan(MountObj.ObsLat)
                            % attempting to move mount when ObsLon/ObsLat
                            % are unknown
                            MountObj.LogFile.writeLog('Attempting to move mount when ObsLon/ObsLat are unknown');
                            error('Attempting to move mount when ObsLon/ObsLat are unknown');
                        end
                            
                        [Flag,FlagRes,Data] = celestial.coo.is_coordinate_ok(RA./RAD, Dec./RAD, JD, ...
                                                                              'Lon', MountObj.ObsLon./RAD, ...
                                                                              'Lat', MountObj.ObsLat./RAD, ...
                                                                              'AltMinConst', MountObj.MinAlt./RAD,...
                                                                              'AzAltConst', MountObj.AzAltLimit./RAD);
                                                                          
                                                                          
                        if Flag

                            % Start slewing
                            MountObj.Handle.goTo(RA, Dec, 'eq');

                            % compare coordinates to requested coordinates

                            % Get error
                            MountObj.LastError = MountObj.Handle.LastError;

                            % Start timer (iOptron only) to notify when slewing is complete
                            switch lower(MountObj.MountType)
                                case 'ioptron'
                                    MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
                                    start(MountObj.SlewingTimer);
                            end
                        else
                            % coordinates are not ok
                            MountObj.LogFile.writeLog('Coordinates are not valid - not slewing to requested target');

                            if ~FlagRes.Alt
                                MountObj.LastError = 'Target Alt too low';
                                MountObj.LogFile.writeLog('Target Alt too low');
                            end
                            if ~FlagRes.AzAlt
                                MountObj.LastError = 'Target Alt too low for local Az';
                                MountObj.LogFile.writeLog('Target Alt too low for local Az');
                            end
                            if ~FlagRes.HA
                                MountObj.LastError = 'Target HA is out of range';
                                MountObj.LogFile.writeLog('Target HA is out of range');
                            end
                        end
                end
            end
        end
    
        function [RAJ,DecJ,HAJ,JD,Aux]=j2000(MountObj,varargin)
            % get J2000.0 distortion corrected coordinates of the mount
            % Input   : - Mount object
            %           - Additional pairs of parameters to pass to celestial.coo.convert2equatorial
            %             Default is no parameters.
            % Output  : - J2000.0 RA [deg]
            %           - J2000.0 Dec [deg]
            %           - J2000.0 HA [deg]
            %           - JD at which the HA was calculated
            %           - Auxilary parameters - see celestial.coo.convert2equatorial
            
            RAD = 180./pi;
            OutputCooType = 'J2000';
            
            % read coordinates from mount
            MRA  = MountObj.RA;
            MDec = MountObj.Dec;
            JD  = celestial.time.julday;
            LST = celestial.time.lst(JD,MountObj.ObsLon./RAD,'a').*360;  % [deg]
            
            % For Xerxes these are tdate, while for iOptron J2000
            switch lower(MountObj.MountType)
                case 'xerxes'
                    InCooType = 'tdate';
                case 'ioptron'
                    InCooType = 'J2000';
                otherwise
                    warning('MountType unknown - assuming Equinox of date');
                    InCooType = 'tdate';
            end
            % input/output are in deg
            [RAJ, DecJ, Aux] = celestial.coo.convert2equatorial(MRA, MDec, varargin{:},'InCooType',InCooType,'OutCooType',OutputCooType);
            HAJ        = LST - RAJ;  % [deg]
            % set HAJ to -180 to 180 deg range
            HAJ        = mod(HAJ,360);
            HAJ(HAJ>180) = HAJ(HAJ>180) -360;
            
            
        end
        
        function RAJ=j2000_RA(MountObj,varargin)
            % like j2000 but return only RA
        
            RAJ = j2000(MountObj,varargin{:});
            
        end
        
        function DecJ=j2000_Dec(MountObj,varargin)
            % like j2000 but return only Dec
        
            [~,DecJ] = j2000(MountObj,varargin{:});
            
        end
        
        function TR_RA=trackingSpeedRA(MountObj)
            % Return tracking rate in RA [deg/s]
            
            Rate  = MountObj.TrackingSpeed;
            TR_RA = Rate(1);
        
        end
        
        function TR_Dec=trackingSpeedDec(MountObj)
            % Return tracking rate in Dec [deg/s]
            
            Rate   = MountObj.TrackingSpeed;
            TR_Dec = Rate(2);
        
        end
        
        function move(Obj)
            % Interactivly moving the mount by clicking a position on image
            
            RAD = 180./pi;
            ARCSEC_IN_DEG = 3600;
            
            % in the future read from the config file
            PixScale = 1.25;
            RAMotionSign  = -1;
            DecMotionSign = -1;
            
            fprintf('Press left click to select a position in image\n')
            %[X,Y,V,Key] = ds9.getcoo(1,'mouse');
            [X,Y,V,Key] = ds9.ginput('image',1,'mouse');
            
            S = ds9.read2sim;
            CenterYX = size(S.Im).*0.5;
            
            % calculate shift relative to image center
            DY = CenterYX(1) - Y;
            DX = CenterYX(2) - X;
            
            RA  = Obj.RA;
            Dec = Obj.Dec;
            
            % convert to J2000.0
            [RA,Dec] = celestial.coo.convert_coo(RA./RAD,Dec./RAD,'tdate','J2000.0');
            RA  = RA.*RAD;
            Dec = Dec.*RAD;
            RA  = RA  + RAMotionSign.* DX.*PixScale./(ARCSEC_IN_DEG.*cosd(Dec));
            Dec = Dec + DecMotionSign.*DY.*PixScale./ARCSEC_IN_DEG;
            
            Obj.goto(RA,Dec,'InCooType','J2000.0');
            
        end
        
        function track(MountObj,Rate)
            % Set tracking rate and start tracking
            % Input  : - Mount object.
            %          - [HA, Dec] speed, if scalar, than Dec speed is set
            %            to zero.
            %            String: 'sidereal' | 'sid' | 'lunar'          
            
            if nargin==2
                % set tracking rate
                MountObj.TrackingSpeed = Rate;
            elseif nargin==1
                Rate = MountObj.TrackingSpeed;
            else
                error('Illegal number of input arguments');
            end
            
            if MountObj.IsConnected
                MountObj.LogFile.writeLog('Start tracking')
                MountObj.Handle.track; % Driver will tarck at sidereal rate
            else
                MountObj.LogFile.writeLog(sprintf('Did not start tracking'));
            end
            MountObj.LastError = MountObj.Handle.LastError;
        end
        
        function home(MountObj)
            % send the mount to its home position as defined by the driver
            
            if MountObj.IsConnected && obs.mount.ismountDriver(MountObj.Handle)
                switch lower(MountObj.Status)
                    case 'park'
                        MountObj.LogFile.writeLog('Can not send mount to home position while parking');
                        MountObj.LastError = 'Can not send mount to home position while parking';
                        if MountObj.Verbose
                            fprintf('Can not send mount to home position while parking\n');
                        end
                    otherwise
                        MountObj.LogFile.writeLog('Slewing home')
                        MountObj.Handle.home;
                        % Start timer to notify when slewing is complete
                        %MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
                        %start(MountObj.SlewingTimer);
                end
            else
                MountObj.LogFile.writeLog('Mount is not connected');
                MountObj.LastError = 'Mount is not connected';
                if MountObj.Verbose
                    fprintf('Mount is not connected\n');
                end

            end
        end
        
        function park(MountObj,ParkState)
            % Park the mount
            % Input  : - True for parking, false for unparking.
            %            Default is true;
            
            if nargin<2
                ParkState = true;
            end
            
            if MountObj.IsConnected && obs.mount.ismountDriver(MountObj.Handle)
                MountObj.LogFile.writeLog(sprintf('Call parking = %d',ParkState));
                
                % Need to check there is no problem with MinAlt
                MountObj.Handle.park(ParkState);
                
                % Start timer to notify when slewing is complete
                MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
                start(MountObj.SlewingTimer);
            else
                MountObj.LogFile.writeLog('Mount is not connected');
                MountObj.LastError = 'Mount is not connected';
                if MountObj.Verbose
                    fprintf('Mount is not connected\n');
                end
                
            end
        end

        
       
        function Flag=isHome(MountObj)
            % check if the mount is at home position as defined by the driver
            
            if MountObj.IsConnected && obs.mount.ismountDriver(MountObj.Handle)
                Flag=MountObj.Handle.isHome;
            else
                Flag = false;
                MountObj.LogFile.writeLog('isHome: Mount is not connected');
                MountObj.LastError = 'isHome: Mount is not connected';
                if MountObj.Verbose
                    fprintf('isHome: Mount is not connected');
                end
            end
        end
        
        function Flag=isSlewing(MountObj)
            % check if the mount is slewing
            
            if MountObj.IsConnected  && obs.mount.ismountDriver(MountObj.Handle)
                Flag=MountObj.Handle.isSlewing;
            else
                Flag = false;
                MountObj.LogFile.writeLog('isSlewing: Mount is not connected');
                MountObj.LastError = 'isSlewing: Mount is not connected';
                if MountObj.Verbose
                    fprintf('isSlewing: Mount is not connected');
                end
           end
        end

        function Flag=isTracking(MountObj)
            % check if the mount is tracking
            
            if MountObj.IsConnected  && obs.mount.ismountDriver(MountObj.Handle)
                Flag = MountObj.Handle.isTracking;
            end
        end

        
        function setCoordinate(MountObj,NewRA,NewDec,MountRA,MountDec,CooSys)
            % Set the mount encoder coordinates to a given values (RA/Dec)
            % Package: +obs/@mount
            % Description: Declare that the current mount position (or an arbitrary position
            %              if more arguments are supplied) has effectively given RA,Dec
            %              coordinates. This is done by shifting .HAZeroPositionTicks and 
            %              .DecZeroPositionTicks of such amounts that the request is fullfilled
            % Input  : - New RA [deg] position, will set the mount RA to this value.
            %          - New Dec [deg] position, will set the mount Dec to this value.
            %          - Mount RA [deg]. If not provided than will read from the
            %            current mount RA. This is always given in Equinox of date.
            %          - Mount Dec [deg]. If not provided than will read from the
            %            current mount Dec. This is always given in Equinox of date.
            %          - Coordinate system of the New RA/Dec: 'J2000' | 'tdate'.
            %            Default is 'J2000'.
            %            Note that the Mount RA/Dec are always in Equinox of date.
            %
            % Usage:
            %
            %  X.setCoordinate(newRA,newDec)  corrects the encoders offsets so that the
            %                                 current mount position is read as (newRA,newDec)
            %                                 All coordinates are in Equinox of Date
            %                                 [deg]
            %
            %  X.setCoordinate(newRA,newDec,RA,Dec)  corrects the encoders offsets so that
            %                                        what is now (RA,Dec) will be pointed
            %                                        to as (newRA,newDec)
            %                                        All coordinates are in Equinox of
            %                                        Date [deg]
            %
            %  Note: in a simplicistic way, this is done simply adding to the encoder zero
            %        positions the differences between old and new coordinates.
            %        Beware!!
            %        Funny things may happen for large corrections, or for corrections
            %        which involve changing flip quadrant (i.e. involving one of the two
            %        sets below the celestial north pole, Dec==180-MotorDec)
            % Examples:
            %       M.setCoordinate(newRA,newDec,mountRA,mountDec)
            %       M.setCoordinate(newRA,newDec)
            %       By : Eran O. Ofek                        Feb 2021
            % Tested   : 12-02-2021/Eran


            % need to read this from the mount object
            %MountConfigFile = 'config.mount_1_1.txt';


            RAD = 180./pi;

            if nargin==6
                % all parameters are supplied by the user
            elseif nargin==5
                CooSys = 'J2000';
            elseif nargin==3
                MountRA  = MountObj.RA;
                MountDec = MountObj.Dec;
                CooSys   = 'J2000';
            elseif nargin==2

                if ischar(NewRA)
                    switch lower(NewRA)
                        case 'reset'
                            MountRA  = MountObj.RA;
                            MountDec = MountObj.Dec;
                            NewRA    = MountRA;
                            NewDec   = MountDec;
                        otherwise
                            error('Unknown string option in second input argument');
                    end
                else
                    error('Illegal input arguments');
                end
            else
                error('Illegal input arguments');
            end

            if ischar(NewRA)
                NewRA = celestial.coo.convertdms(NewRA,'SH','d');
            end
            if ischar(NewDec)
                NewDec = celestial.coo.convertdms(NewDec,'SD','d');
            end

            % convert coordinate systems
            switch lower(CooSys)
                case {'tdate','jdate','jnow'}
                    % do nothing
                    % NewRA, NewDec are already in Equinox of date
                case {'j2000.0','j2000'}
                    % NewRA, NewDec are given in J2000
                    % convert [NewRA,NewDec] to Jnow
                    JD = celestial.time.julday; % JD, UTC now
                    JnowStr = sprintf('j%8.3f',convert.time(JD,'JD','J'));
                    NewCoo  = celestial.coo.coco([NewRA,NewDec]./RAD,'j2000.0',JnowStr);
                    NewRA   = NewCoo(1).*RAD;
                    NewDec  = NewCoo(2).*RAD;
                otherwise
                    error('Unknown CooSys option');
            end

            % update the encoders position
            %MountObj.Handle.setCoordinate(NewRA,NewDec,MountRA,MountDec);

            switch lower(MountObj.MountType)
                case 'ioptron'
                    % not supported
                    error('setCoordinate is not supported for iOptron mount');
                    
                case 'xerxes'
            
                    haOffset=(mod(NewRA-MountRA+180,360)-180)*MountObj.Handle.EncoderTicksPerDegree;
                    % for Dec, we do not bother wrapping around, modulo, etc., because
                    %  doing so would imply handling flip
                    decOffset=(NewDec-MountDec)*MountObj.Handle.EncoderTicksPerDegree;

                    
                    % read current mount config file
                    [ConfigLogical,ConfigPhysical,~,~] = readConfig(MountObj,[MountObj.NodeNumber, MountObj.MountNumber]);
                    
                    % write offsets in object
                    % RA sign is +1 (in test mount)
                    % Dec sign is -1 (in test mount)
                    HAZeroPositionTicks    = MountObj.Handle.HAZeroPositionTicks  + ConfigPhysical.RA_encoder_direction .*haOffset;
                    DecZeroPositionTicks   = MountObj.Handle.DecZeroPositionTicks + ConfigPhysical.Dec_encoder_direction.*decOffset;
                    MountObj.Handle.HAZeroPositionTicks  = HAZeroPositionTicks;
                    MountObj.Handle.DecZeroPositionTicks = DecZeroPositionTicks;
    
                    % update offsets in config file
                    %configfile.replace_config(ConfigFile,'HAZeroPositionTicks',sprintf('%9d',HAZeroPositionTicks),'ticks');
                    %configfile.replace_config(ConfigFile,'DecZeroPositionTicks',sprintf('%9d',DecZeroPositionTicks),'ticks');
                    MountObj.updateConfiguration(MountObj.Config,'HAZeroPositionTicks',sprintf('%9d',HAZeroPositionTicks),'ticks');
                    MountObj.updateConfiguration(MountObj.Config,'DecZeroPositionTicks',sprintf('%9d',DecZeroPositionTicks),'ticks');

                otherwise
                    error('Unknown MountType option');
            end

        end
        
        
        
    end
    
    % utilities
    methods 
    
        function callback_timer(MountObj, ~, ~)
            % After slewing, check if mount is in Idle status 

            if (~strcmp(MountObj.Status, 'slewing'))
               stop(MountObj.SlewingTimer);
               % beep
               MountObj.LogFile.writeLog('Slewing is complete')
               %   if MountObj.Verbose, fprintf('Slewing is complete\n'); end
            end
        
        end
        
        function Flag = waitFinish(MountObj)
            % wait (blocking) until the mount ended slewing and returned to idle mode
            
            Flag = false;
            Continue = true;
            while Continue
                pause(1);
                try
                    Status = MountObj.Status;
                catch
                    pause(1);
                    Status = MountObj.Status;
                end


                switch lower(Status)
                    case {'idle','tracking','home','park','aborted','disabled'}

                        if MountObj.Verbose
                            fprintf('\nSlewing is complete\n');
                        end
                        Continue = false;
                        Flag = true;
                        
                    case 'slewing'
                        if MountObj.Verbose
                            fprintf('.');
                        end
                    otherwise
                        MountObj.LogFile.writeLog(sprintf('Unknown mount status %s',Status));
                        MountObj.LastError = sprintf('Unknown mount status %s',Status);
                        Continue = false;
                end
            end
        end

        function LST=lst(MountObj)
            % Get the Local Siderial Time (LST) in [deg]

            RAD = 180./pi;
            % Get JD from the computer
            JD = celestial.time.julday;
            LST = celestial.time.lst(JD,MountObj.ObsLon./RAD);  % fraction of day
            LST = LST.*360;
        end

    end
    
end
