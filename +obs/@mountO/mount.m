% mount control handle class
% Package: +obs/@mount
% Description: operate mount drivers.
%              Currently can work with Xerxes, iOptron and Celestron mounts
% Input  : none.
% Output : A mount class
%     By :
% Example:  M = obs.mount;
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
        RA            % Deg
        Dec           % Deg
        HA            % Deg
        Az            % Deg
        Alt           % Deg
        TrackingSpeed % Deg/s
    end

    properties(GetAccess=public, SetAccess=private)
        % Mount configuration
        Status      = 'unknown';
        IsEastOfPier = NaN;
    end

    properties(Hidden)
        Handle;
        LastError = 'unknown';
        LastRC    = '';
        LogFile;
        Verbose   = true; % for stdin debugging

        IsConnected = false; % Connection status between class to camera
        TimeFromGPS = false; % default is no, take time and coordinates from computer
        IsCounterWeightDown=true; % Test that this works as expected

        IPaddress = '';
        Port = '';
        SerialResource % the serial object corresponding to Port

        % Mount and telescopes names and models
        MountType = '';
        MountModel = '';
        MountUniqueName = '';
        MountGeoName = '';
        TelescopeEastUniqueName = '';
        TelescopeWestUniqueName = '';
        
        MinAlt      = 15;
        AzAltLimit  = [[0, 0];[90, 10];[180, 15];[270, 10];[360, 0]];
        MinAzAltMap = NaN;
        MinAltPrev = NaN;
        MeridianFlip=true; % if false, stop at the meridian limit
        MeridianLimit=92; % Test that this works as expected, no idea what happens
        
        SlewingTimer;
        DistortionFile = '';

        MountPos=[NaN,NaN,NaN];
        MountCoo = struct('ObsLon',NaN,'ObsLat',NaN,'ObsHeight',NaN);
        MountUTC
        ParkPos = [NaN,NaN]; % park pos in [Az,Alt] (negative Alt is impossible)
    end
    
    % non-API-demanded properties, Enrico's judgement
    properties (Hidden) 
%?        SerialResource % the serial object corresponding to Port
    end
    
    properties (Hidden, GetAccess=public, SetAccess=private, Transient)
    end
    
    properties(Hidden,Constant)
        SiderealRate = 360/86164.0905; %sidereal tracking rate, degrees/sec
        
%          % empirical slewing rate (fixed?), degrees/sec, excluding accelerations
%          % if it could be varied (see ':GSR#'/':MSRn#'), this won't be a 
%          % Constant property
%         slewRate = 2.5;
    end

    methods
        % constructor and destructor
        function MountObj=mount(MountType)  
            % mount class constructor
            % Package: +obs/@mount
            % Input  : - Mount type ['xerxes'] | 'ioptron'
            %
            
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
            
            %if(strcmp(MountObj.MountType, 'Xerxes'))
            %   MountObj.Handle=inst.XerxesMount();
            %elseif(strcmp(MountObj.MountType, 'iOptron'))
            %   MountObj.Handle=inst.iOptronCEM120();
            %end
        end

        function delete(MountObj)
            % delete mount object and related sub objects
            MountObj.Handle.delete;
            % Delete the timer
            delete(MountObj.SlewingTimer);
% %            fclose(MountObj);
%             % shall we try-catch and report success/failure?
        end
        
    end
    
    methods

        % Get the unique serial name of the mount
        function MountUniqueName=get.MountUniqueName(MountObj)
            % Get the unique serial name of the mount
            MountUniqueName = MountObj.MountUniqueName;
        end

        % Get the 'geographic' number of the mount within the observing
        % building
        function MountGeoName=get.MountGeoName(MountObj)
            MountGeoName = MountObj.MountGeoName;
        end

        % Get the unique serial name of the eastern telescope (when pointed North)
        function TelescopeEastUniqueName=get.TelescopeEastUniqueName(MountObj)
            TelescopeEastUniqueName = MountObj.TelescopeEastUniqueName;
        end

        % Get the unique serial name of the western telescope (when pointed North)
        function TelescopeWestUniqueName=get.TelescopeWestUniqueName(MountObj)
            TelescopeWestUniqueName = MountObj.TelescopeWestUniqueName;
        end

        % setters and getters
        function Az=get.Az(MountObj)
           if MountObj.checkIfConnected
               try
                  Az = MountObj.Handle.Az;
               catch
                  pause(1);
                  try
                     Az = MountObj.Handle.Az;
                  catch
                     Az = [];
                     MountObj.LastError = "Cannot get Az";
                  end
               end
           end
        end

        function set.Az(MountObj,Az)
           if MountObj.checkIfConnected
                if (~strcmp(MountObj.Status, 'park'))

                    % Delete calling a timer to wait for slewing complete,
                    % because a conflict with Xerexs. DP Feb 8, 2021
%                    % Start timer to notify when slewing is complete
%                    MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
%                    start(MountObj.SlewingTimer);

                   MountObj.Handle.Az = Az;
                   MountObj.LastError = MountObj.Handle.LastError;
                else
                   MountObj.LastError = "Cannot slew, telescope is parking. Run: park(0)";
                end
           end
        end
        
        function Alt=get.Alt(MountObj)
           if MountObj.checkIfConnected
               try
                  Alt = MountObj.Handle.Alt;
               catch
                  pause(1);
                  try
                     Alt = MountObj.Handle.Alt;
                  catch
                     Alt = [];
                     MountObj.LastError = "Cannot get Alt";
                  end
               end
           end
        end

        function set.Alt(MountObj,Alt)
           if MountObj.checkIfConnected
               if (~strcmp(MountObj.Status, 'park'))
                  if (Alt >= MountObj.MinAlt)

                    % Delete calling a timer to wait for slewing complete,
                    % because a conflict with Xerexs. DP Feb 8, 2021
%                      % Start timer to notify when slewing is complete
%                      MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
%                      start(MountObj.SlewingTimer);

                     MountObj.Handle.Alt = Alt;
                     MountObj.LastError = MountObj.Handle.LastError;
                  else
                     MountObj.LastError = "target Alt beyond limits";
                  end
               else
                  MountObj.LastError = "Cannot slew, telescope is parking. Run: park(0)";
               end
           end
        end

        function RA=get.RA(MountObj)
           if MountObj.checkIfConnected
               try
                  RA = MountObj.Handle.RA;
               catch
                  pause(1);
                  try
                     RA = MountObj.Handle.RA;
                  catch
                     RA = [];
                     MountObj.LastError = "Cannot get RA";
                  end
               end
           end
        end

        function set.RA(MountObj,RA)
           if MountObj.checkIfConnected
              MountObj.Handle.RA = RA;
           end
        end

        function Dec=get.Dec(MountObj)
           if MountObj.checkIfConnected
               try
                  Dec = MountObj.Handle.Dec;
               catch
                   pause(1);
                   try
                      Dec = MountObj.Handle.Dec;
                   catch
                      Dec = [];
                      MountObj.LastError = "Cannot get Dec";
                   end
               end
           end
        end

        function set.Dec(MountObj,Dec)
           if MountObj.checkIfConnected
              MountObj.Handle.Dec = Dec;
           end
        end

        function HA=get.HA(MountObj)
           if MountObj.checkIfConnected
               try
                  HA = MountObj.Handle.HA;
               catch
                  pause(1);
                  try
                     HA = MountObj.Handle.HA;
                  catch
                     HA = [];
                     MountObj.LastError = "Cannot get HA";
                  end
               end
           end
        end

        function set.HA(MountObj,HA)
           if MountObj.checkIfConnected
              MountObj.Handle.HA = HA;
           end
        end

        function EastOfPier=get.IsEastOfPier(MountObj)
           if MountObj.checkIfConnected
               % True if east, false if west.
               % Assuming that the mount is polar aligned
               EastOfPier = MountObj.Handle.IsEastOfPier;
           end
        end

        function CounterWeightDown=get.IsCounterWeightDown(MountObj)
           if MountObj.checkIfConnected
              CounterWeightDown = MountObj.Handle.IsCounterWeightDown;
           end
        end
        
%         function S=get.FullStatus(MountObj)
%             if MountObj.checkIfConnected
%             S = MountObj.Handle.FullStatus;
%            end
%         end
        
        function flag=get.TimeFromGPS(MountObj)
            % At this stage - Xerxes and iOptron will read time/location from
            % the computer, so always return false. DP Feb 2021.
            flag = false;
%             if MountObj.checkIfConnected
%                flag=MountObj.Handle.TimeFromGPS;
%             end
        end
        
        function S=get.Status(MountObj)
           % Status of the mount: idle, slewing, park, home, tracking, unknown
           if MountObj.checkIfConnected
               try
                  S = MountObj.Handle.Status;
               catch
                  pause(1);
                  try
                     S = MountObj.Handle.Status;
                  catch
                     S = 'unknown';
                     MountObj.LastError = "Cannot get Telescope status";
                  end
               end
           end
        end
        
        % tracking implemented by setting the property TrackingSpeed.
        %  using custom tracking mode, which allows the broadest range
        
        function TrackSpeed=get.TrackingSpeed(MountObj)
           % Get the current Trackuing speed in [deg/s]
           if MountObj.checkIfConnected
              TrackSpeed = MountObj.Handle.TrackingSpeed;
           end
        end

        function set.TrackingSpeed(MountObj,Speed)
            % set the Tracking speed in (RA, Dec) [deg/s]
            % Input  : - self
            %          - [RA, Dec] tracking rate in deg/s.
            %            Alternatively, this can be a string 'sidereal',
            %            whicj will set the RA tracking rate to the
            %            sidereal rate.
            
            if MountObj.checkIfConnected
                if ischar(Speed)
                    switch lower(Speed)
                        case 'sidereal'
                            Speed=MountObj.SiderealRate;
                        otherwise
                            error('Unknown Tracking rate string');
                    end
                end
                    
                %if (strcmp(Speed,'Sidereal'))
                %    Speed=MountObj.SiderealRate;
                %end
                
                MountObj.Handle.TrackingSpeed = Speed;

                MountObj.LastError = MountObj.Handle.LastError;
            end
        end

% functioning parameters getters/setters & misc
        
        function flip=get.MeridianFlip(MountObj)
           if MountObj.checkIfConnected
              flip = MountObj.Handle.MeridianFlip;
           end
        end
        
        function set.MeridianFlip(MountObj,flip)
            if MountObj.checkIfConnected
               MountObj.Handle.MeridianFlip = flip;
               MountObj.LastError = MountObj.Handle.LastError;
            end
        end

        function limit=get.MeridianLimit(MountObj)
           if MountObj.checkIfConnected
               limit = MountObj.Handle.MeridianLimit;
           end
        end
        
        function set.MeridianLimit(MountObj,limit)
           if MountObj.checkIfConnected
              MountObj.Handle.MeridianLimit = limit;
              MountObj.LastError = MountObj.Handle.LastError;
           end
        end
        
        function MinAlt=get.MinAlt(MountObj)
            if MountObj.checkIfConnected
               MinAlt = MountObj.Handle.MinAlt;
            end
        end
        
        function set.MinAlt(MountObj,MinAlt)
           if MountObj.checkIfConnected
              MountObj.Handle.MinAlt = MinAlt;
              MountObj.LastError = MountObj.Handle.LastError;
            end
        end
       
        function MinAzAltMap=get.MinAzAltMap(MountObj)
            MinAzAltMap = MountObj.MinAzAltMap;
        end
        
        function set.MinAzAltMap(MountObj,MinAzAltMap)
            [~,co] = size(MinAzAltMap);
            if(co == 2)
               MountObj.MinAzAltMap = MinAzAltMap;
            else
               MountObj.LastError = 'Format is 2-column table: Az, Alt\n';
            end
        end
       
        function ParkPosition=get.ParkPos(MountObj)
            if MountObj.checkIfConnected
               ParkPosition = MountObj.Handle.ParkPos;
            end
        end

        function set.ParkPos(MountObj,pos)
            if MountObj.checkIfConnected
               MountObj.Handle.ParkPos = pos;
               MountObj.LastError = MountObj.Handle.LastError;
            end
        end
        
        function MountPos=get.MountPos(MountObj)
            if MountObj.checkIfConnected
               MountPos = MountObj.Handle.MountPos;
            end
        end
            
        function set.MountPos(MountObj,Position)
            if MountObj.checkIfConnected
               MountObj.Handle.MountPos = Position;
               MountObj.LastError = MountObj.Handle.LastError;
            end
        end

        %%% NEEDS TO THINK HOW TO HANDLE MountCoo and MountPos - DP 2020 Jul
        function MountCoo=get.MountCoo(MountObj)
%            MountCoo           = MountObj.Handle.MountPos;
            MountCoo.ObsLon    = MountObj.Handle.MountPos(1);
            MountCoo.ObsLat    = MountObj.Handle.MountPos(2);
            MountCoo.ObsHeight = MountObj.Handle.MountPos(3);
        end
        
%         function set.MountCoo(MountObj,Position)
%            if MountObj.checkIfConnected
%               MountObj.MountCoo.ObsLon    = Position(1);
%               MountObj.MountCoo.ObsLat    = Position(2);
%               MountObj.MountCoo.ObsHeight = Position(3);
% 
%               MountObj.Handle.MountPos = Position;
%               MountObj.LastError = MountObj.Handle.LastError;
%            end
%         end

        % Get the last error reported by the driver code
        function LastError=get.LastError(MountObj)
            LastError = MountObj.Handle.LastError;
            MountObj.LogFile.writeLog(LastError)
            if MountObj.Verbose, fprintf('%s\n', LastError); end
        end

        % Set an error, update log and print to command line
        function set.LastError(MountObj,LastError)
           % If the LastError is empty (e.g. if the previous command did
           % not fail), do not keep or print it,
           if (~isempty(LastError))
              % If the error message is taken from the driver object, do NOT
              % update the driver object.
%               if (~strcmp(MountObj.Handle.LastError, LastError))
%                  MountObj.Handle.LastError = LastError;
%               end
              MountObj.LogFile.writeLog(LastError)
              if MountObj.Verbose, fprintf('%s\n', LastError); end
           end
        end

        % Get the mount IPaddress
        function IPaddress=get.IPaddress(MountObj)
            IPaddress = MountObj.IPaddress;
        end

        % Get the computer USB port to connect to the mount
        function Port=get.Port(MountObj)
            Port = MountObj.Handle.Port;
        end

        % Get the serial object corresponding to Port
        function SerialResource=get.SerialResource(MountObj)
            SerialResource = MountObj.Handle.SerialResource;
        end

        function MountUTC=get.MountUTC(MountObj)
            % Returns mount UTC clock. Units: Julian Date
            MountUTC = MountObj.Handle.MountUTC;
        end
            
        function set.MountUTC(MountObj, dummy)
           % Set the mount UTC clock from the computer clock. Units: Julian Date - use with care
           % dummy argument is not used.
           MountObj.Handle.MountUTC = dummy;
        end

    end
    
    methods
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
    end
    
end
