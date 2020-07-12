classdef mount <handle

    properties (Dependent)
        % mount direction and motion
        RA            % Deg
        Dec           % Deg
        Az            % Deg
        Alt           % Deg
        TrackingSpeed % Deg/s
    end

    properties(GetAccess=public, SetAccess=private)
        % Mount configuration
        Status      = 'unknown';
        IsConnected = false; % Connection status between class to camera
        TimeFromGPS = false; % default is no, take time and coordinates from computer
        IsEastOfPier = NaN;
        IsCounterWeightDown=true; % Test that this works as expected
        
        MinAlt = 15;
        MinAzAltMap = NaN;
        
        MountPos=[NaN,NaN,NaN];
        MountCoo = struct('ObsLon',NaN,'ObsLat',NaN,'ObsHeight',NaN);
        MountUTC
        ParkPos = [NaN,NaN]; % park pos in [Az,Alt] (negative Alt is impossible)
    end

    properties(Hidden)
        MouHn;
        LogFile;
        Verbose = true; % for stdin debugging

        Port
        Serial_resource % the serial object corresponding to Port

        % Mount and telescopes names and models
        MountType = NaN;
        MountModel = NaN;
        MountUniqueName = NaN;
        MountGeoName = NaN;
        TelescopeEastUniqueName = NaN;
        TelescopeWestUniqueName = NaN;
        
        MinAltPrev = NaN;
        MeridianFlip=true; % if false, stop at the meridian limit
        MeridianLimit=92; % Test that this works as expected, no idea what happens
        
        SlewingTimer;
        DistortionFile = '';

    end
    
    % non-API-demanded properties, Enrico's judgement
    properties (Hidden) 
%?        serial_resource % the serial object corresponding to Port
    end
    
    properties (Hidden, GetAccess=public, SetAccess=private, Transient)
        LastError='';
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
        function MountObj=mount()
       
           % Construct directory for log file
           DirName = util.constructDirName('log');
           cd(DirName);

           % Opens Log for the mount
           MountObj.LogFile = logFile;
           MountObj.LogFile.Dir = DirName;
           MountObj.LogFile.FileNameTemplate = 'LAST_%s.log';
           MountObj.LogFile.logOwner = sprintf('%s.%s.%s_%s_Mount', ...
                                       util.readSystemConfigFile('ObservatoryNode'), util.readSystemConfigFile('MountGeoName'), util.readSystemConfigFile('CamGeoName'), DirName(end-7:end));

            
           % Open a driver object for the mount
           MountObj.MouHn=inst.iOptronCEM120();
        end
        
        function delete(MountObj)
            MountObj.MouHn.delete;
            % Delete the timer
            delete(MountObj.SlewingTimer);
% %            fclose(MountObj);
%             % shall we try-catch and report success/failure?
        end
        
    end
    
    methods

        % Get the unique serial name of the mount
        function MountUniqueName=get.MountUniqueName(MountObj)
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
%%%           MountObj.checkIfConnected
           try
              Az = MountObj.MouHn.Az;
           catch
              pause(1);
              try
                 Az = MountObj.MouHn.Az;
              catch
                 Az = [];
                 MountObj.LastError = "Cannot get Az";
              end
           end
        end

        function set.Az(MountObj,Az)
%%%            MountObj.checkIfConnected
            if (~strcmp(MountObj.Status, 'park'))

               % Start timer to notify when slewing is complete
               MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
               start(MountObj.SlewingTimer);

               MountObj.MouHn.Az = Az;
               if (~isempty(MountObj.MouHn.lastError))
                  MountObj.LastError = MountObj.MouHn.lastError;
               end
            else
               MountObj.LastError = "Cannot slew, telescope is parking. Run: park(0)";
            end
        end
        
        function Alt=get.Alt(MountObj)
%%%           MountObj.checkIfConnected
           try
              Alt = MountObj.MouHn.Alt;
           catch
              pause(1);
              try
                 Alt = MountObj.MouHn.Alt;
              catch
                 Alt = [];
                 MountObj.LastError = "Cannot get Alt";
              end
           end
        end
        
        function set.Alt(MountObj,Alt)
%%%           MountObj.checkIfConnected
           if (~strcmp(MountObj.Status, 'park'))
              if (Alt >= MountObj.MinAlt)

                 % Start timer to notify when slewing is complete
                 MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
                 start(MountObj.SlewingTimer);

                 MountObj.MouHn.Alt = Alt;
                 
                 if (~isempty(MountObj.MouHn.lastError))
                    MountObj.LastError = MountObj.MouHn.lastError;
                 end
              else
                 MountObj.LastError = "target Alt beyond limits";
              end
           else
              MountObj.LastError = "Cannot slew, telescope is parking. Run: park(0)";
           end
        end

        function RA=get.RA(MountObj)
%%%           MountObj.checkIfConnected
           try
              RA = MountObj.MouHn.RA;
           catch
              pause(1);
              try
                 RA = MountObj.MouHn.RA;
              catch
                 RA = [];
                 MountObj.LastError = "Cannot get RA";
              end
           end
        end

        function set.RA(MountObj,RA)
%%%           MountObj.checkIfConnected
           MountObj.MouHn.RA = RA;
        end

        function Dec=get.Dec(MountObj)
%%%            MountObj.checkIfConnected
           try
              Dec = MountObj.MouHn.Dec;
           catch
               pause(1);
               try
                  Dec = MountObj.MouHn.Dec;
               catch
                  Dec = [];
                  MountObj.LastError = "Cannot get Dec";
               end
           end
        end
        
        function set.Dec(MountObj,Dec)
%%%           MountObj.checkIfConnected
           MountObj.MouHn.Dec = Dec;
        end
                
        function EastOfPier=get.IsEastOfPier(MountObj)
%%%           MountObj.checkIfConnected
           % True if east, false if west.
           % Assuming that the mount is polar aligned
           EastOfPier = MountObj.MouHn.isEastOfPier;
        end

        function CounterWeightDown=get.IsCounterWeightDown(MountObj)
%%%           MountObj.checkIfConnected
           CounterWeightDown = MountObj.MouHn.isCounterweightDown;
        end
        
%         function S=get.fullStatus(MountObj)
% %%%            MountObj.checkIfConnected
%             S = MountObj.MouHn.fullStatus;
%         end
        
        function flag=get.TimeFromGPS(MountObj)
%%%            MountObj.checkIfConnected
            flag=MountObj.MouHn.TimeFromGPS;
        end
        
        function S=get.Status(MountObj)
            % Status of the mount: idle, slewing, park, home, tracking, unknown
%%%            MountObj.checkIfConnected
           try
              S = MountObj.MouHn.Status;
           catch
              pause(1);
              try
                 S = MountObj.MouHn.Status;
              catch
                 S = 'unknown';
                 MountObj.LastError = "Cannot get Telescope status";
              end
           end
        end
        
        % tracking implemented by setting the property TrackingSpeed.
        %  using custom tracking mode, which allows the broadest range
        
        function TrackSpeed=get.TrackingSpeed(MountObj)
%%%            MountObj.checkIfConnected
            TrackSpeed = MountObj.MouHn.TrackingSpeed;
        end

        function set.TrackingSpeed(MountObj,Speed)
%%%            MountObj.checkIfConnected
            if (strcmp(Speed,'Sidereal'))
               Speed=MountObj.SiderealRate;
            end
            MountObj.MouHn.TrackingSpeed = Speed;
            
            if (~isempty(MountObj.MouHn.lastError))
               MountObj.LastError = MountObj.MouHn.lastError;
            end
        end

% functioning parameters getters/setters & misc
        
        function flip=get.MeridianFlip(MountObj)
%%%            MountObj.checkIfConnected
            flip = MountObj.MouHn.MeridianFlip;
        end
        
        function set.MeridianFlip(MountObj,flip)
%%%            MountObj.checkIfConnected
            MountObj.MouHn.MeridianFlip = flip;
            if (~isempty(MountObj.MouHn.lastError))
               MountObj.LastError = MountObj.MouHn.lastError;
            end
        end

        function limit=get.MeridianLimit(MountObj)
%%%            MountObj.checkIfConnected
            limit = MountObj.MouHn.MeridianLimit;
        end
        
        function set.MeridianLimit(MountObj,limit)
%%%            MountObj.checkIfConnected
            MountObj.MouHn.MeridianLimit = limit;
            if (~isempty(MountObj.MouHn.lastError))
               MountObj.LastError = MountObj.MouHn.lastError;
            end
        end
        
        function MinAlt=get.MinAlt(MountObj)
%%%            MountObj.checkIfConnected
            MinAlt = MountObj.MouHn.MinAlt;
        end
        
        function set.MinAlt(MountObj,MinAlt)
%%%            MountObj.checkIfConnected
            MountObj.MouHn.MinAlt = MinAlt;
            if (~isempty(MountObj.MouHn.lastError))
               MountObj.LastError = MountObj.MouHn.lastError;
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
%%%            MountObj.checkIfConnected
            ParkPosition = MountObj.MouHn.ParkPos;
        end

        function set.ParkPos(MountObj,pos)
%%%            MountObj.checkIfConnected
            MountObj.MouHn.ParkPos = pos;
            if (~isempty(MountObj.MouHn.lastError))
               MountObj.LastError = MountObj.MouHn.lastError;
            end
        end
        
        function MountPos=get.MountPos(MountObj)
%%%            MountObj.checkIfConnected
            MountPos = MountObj.MouHn.MountPos;
        end
            
        function set.MountPos(MountObj,Position)
%%%            MountObj.checkIfConnected
            MountObj.MouHn.MountPos = Position;
            if (~isempty(MountObj.MouHn.lastError))
               MountObj.LastError = MountObj.MouHn.lastError;
            end
        end

        function MountCoo=get.MountCoo(MountObj)
%            MountCoo           = MountObj.MouHn.MountPos;
            MountCoo.ObsLon    = MountObj.MouHn.MountPos(1);
            MountCoo.ObsLat    = MountObj.MouHn.MountPos(2);
            MountCoo.ObsHeight = MountObj.MouHn.MountPos(3);
        end
        
%         function set.MountCoo(MountObj,Position)
% %%%            MountObj.checkIfConnected
%            MountObj.MountCoo.ObsLon    = Position(1);
%            MountObj.MountCoo.ObsLat    = Position(2);
%            MountObj.MountCoo.ObsHeight = Position(3);
% 
%            MountObj.MouHn.MountPos = Position;
%            if (~isempty(MountObj.MouHn.lastError))
%               MountObj.LastError = MountObj.MouHn.lastError;
%            end
%         end

        % Get the last error reported by the driver code
        function LastError=get.LastError(MountObj)
            LastError = MountObj.MouHn.lastError;
            MountObj.LogFile.writeLog(LastError)
            if MountObj.Verbose, fprintf('%s\n', LastError); end
        end

        % Set an error, update log and print to command line
        function set.LastError(MountObj,LastError)
            MountObj.LastError = LastError;
            MountObj.LogFile.writeLog(MountObj.LastError)
            if MountObj.Verbose, fprintf('%s\n', MountObj.LastError); end
        end
        
        % Get the computer port connected to the mount
        function Port=get.Port(MountObj)
            Port = MountObj.MouHn.Port;
        end

        % Get the serial object corresponding to Port
        function Serial_resource=get.Serial_resource(MountObj)
            Serial_resource = MountObj.MouHn.serial_resource;
        end

        function MountUTC=get.MountUTC(MountObj)
            % Returns mount UTC clock. Units: Julian Date
            MountUTC = MountObj.MouHn.MountUTC;
        end
            
        function set.MountUTC(MountObj, dummy)
           % Set the mount UTC clock from the computer clock. Units: Julian Date - use with care
           % dummy argument is not used.
           MountObj.MouHn.MountUTC = dummy;
        end

    end
end
