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
        IsEastOfPier = NaN;
    end

    properties(Hidden)
        MouHn;
        LastError = 'unknown';
        LastRC    = '';
        LogFile;
        Verbose   = true; % for stdin debugging

        IsConnected = false; % Connection status between class to camera
        TimeFromGPS = false; % default is no, take time and coordinates from computer
        IsCounterWeightDown=true; % Test that this works as expected

        Port
        Serial_resource % the serial object corresponding to Port

        % Mount and telescopes names and models
        MountType = NaN;
        MountModel = NaN;
        MountUniqueName = NaN;
        MountGeoName = NaN;
        TelescopeEastUniqueName = NaN;
        TelescopeWestUniqueName = NaN;
        
        MinAlt = 15;
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
%?        serial_resource % the serial object corresponding to Port
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
        function MountObj=mount()
       
           % Construct directory for log file
           DirName = obs.util.constructDirName('log');
           cd(DirName);

           % Opens Log for the mount
           MountObj.LogFile = logFile;
           MountObj.LogFile.Dir = DirName;
           MountObj.LogFile.FileNameTemplate = 'LAST_%s.log';
           MountObj.LogFile.logOwner = sprintf('%s.%s.%s_%s_Mount', ...
                                       obs.util.readSystemConfigFile('ObservatoryNode'), obs.util.readSystemConfigFile('MountGeoName'), obs.util.readSystemConfigFile('CamGeoName'), DirName(end-7:end));

            
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
           if MountObj.checkIfConnected
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
        end

        function set.Az(MountObj,Az)
           if MountObj.checkIfConnected
                if (~strcmp(MountObj.Status, 'park'))

                   % Start timer to notify when slewing is complete
                   MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
                   start(MountObj.SlewingTimer);

                   MountObj.MouHn.Az = Az;
                   MountObj.LastError = MountObj.MouHn.lastError;
                else
                   MountObj.LastError = "Cannot slew, telescope is parking. Run: park(0)";
                end
           end
        end
        
        function Alt=get.Alt(MountObj)
           if MountObj.checkIfConnected
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
        end

        function set.Alt(MountObj,Alt)
           if MountObj.checkIfConnected
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
        end

        function RA=get.RA(MountObj)
           if MountObj.checkIfConnected
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
        end

        function set.RA(MountObj,RA)
           if MountObj.checkIfConnected
              MountObj.MouHn.RA = RA;
           end
        end

        function Dec=get.Dec(MountObj)
           if MountObj.checkIfConnected
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
        end

        function set.Dec(MountObj,Dec)
           if MountObj.checkIfConnected
              MountObj.MouHn.Dec = Dec;
           end
        end

        function EastOfPier=get.IsEastOfPier(MountObj)
           if MountObj.checkIfConnected
               % True if east, false if west.
               % Assuming that the mount is polar aligned
               EastOfPier = MountObj.MouHn.isEastOfPier;
           end
        end

        function CounterWeightDown=get.IsCounterWeightDown(MountObj)
           if MountObj.checkIfConnected
              CounterWeightDown = MountObj.MouHn.isCounterweightDown;
           end
        end
        
%         function S=get.fullStatus(MountObj)
%             if MountObj.checkIfConnected
%             S = MountObj.MouHn.fullStatus;
%            end
%         end
        
        function flag=get.TimeFromGPS(MountObj)
            if MountObj.checkIfConnected
               flag=MountObj.MouHn.TimeFromGPS;
            end
        end
        
        function S=get.Status(MountObj)
            % Status of the mount: idle, slewing, park, home, tracking, unknown
           if MountObj.checkIfConnected
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
        end
        
        % tracking implemented by setting the property TrackingSpeed.
        %  using custom tracking mode, which allows the broadest range
        
        function TrackSpeed=get.TrackingSpeed(MountObj)
           if MountObj.checkIfConnected
              TrackSpeed = MountObj.MouHn.TrackingSpeed;
           end
        end

        function set.TrackingSpeed(MountObj,Speed)
           if MountObj.checkIfConnected
              if (strcmp(Speed,'Sidereal'))
                 Speed=MountObj.SiderealRate;
              end
              MountObj.MouHn.TrackingSpeed = Speed;
            
              MountObj.LastError = MountObj.MouHn.lastError;
           end
        end

% functioning parameters getters/setters & misc
        
        function flip=get.MeridianFlip(MountObj)
           if MountObj.checkIfConnected
              flip = MountObj.MouHn.MeridianFlip;
           end
        end
        
        function set.MeridianFlip(MountObj,flip)
            if MountObj.checkIfConnected
               MountObj.MouHn.MeridianFlip = flip;
               MountObj.LastError = MountObj.MouHn.lastError;
            end
        end

        function limit=get.MeridianLimit(MountObj)
           if MountObj.checkIfConnected
               limit = MountObj.MouHn.MeridianLimit;
           end
        end
        
        function set.MeridianLimit(MountObj,limit)
           if MountObj.checkIfConnected
              MountObj.MouHn.MeridianLimit = limit;
              MountObj.LastError = MountObj.MouHn.lastError;
           end
        end
        
        function MinAlt=get.MinAlt(MountObj)
            if MountObj.checkIfConnected
               MinAlt = MountObj.MouHn.MinAlt;
            end
        end
        
        function set.MinAlt(MountObj,MinAlt)
           if MountObj.checkIfConnected
              MountObj.MouHn.MinAlt = MinAlt;
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
            if MountObj.checkIfConnected
               ParkPosition = MountObj.MouHn.ParkPos;
            end
        end

        function set.ParkPos(MountObj,pos)
            if MountObj.checkIfConnected
               MountObj.MouHn.ParkPos = pos;
               MountObj.LastError = MountObj.MouHn.lastError;
            end
        end
        
        function MountPos=get.MountPos(MountObj)
            if MountObj.checkIfConnected
               MountPos = MountObj.MouHn.MountPos;
            end
        end
            
        function set.MountPos(MountObj,Position)
            if MountObj.checkIfConnected
               MountObj.MouHn.MountPos = Position;
               MountObj.LastError = MountObj.MouHn.lastError;
            end
        end

        %%% NEEDS TO THINK HOW TO HANDLE MountCoo and MountPos - DP 2020 Jul
        function MountCoo=get.MountCoo(MountObj)
%            MountCoo           = MountObj.MouHn.MountPos;
            MountCoo.ObsLon    = MountObj.MouHn.MountPos(1);
            MountCoo.ObsLat    = MountObj.MouHn.MountPos(2);
            MountCoo.ObsHeight = MountObj.MouHn.MountPos(3);
        end
        
%         function set.MountCoo(MountObj,Position)
%            if MountObj.checkIfConnected
%               MountObj.MountCoo.ObsLon    = Position(1);
%               MountObj.MountCoo.ObsLat    = Position(2);
%               MountObj.MountCoo.ObsHeight = Position(3);
% 
%               MountObj.MouHn.MountPos = Position;
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
           % If the LastError is empty (e.g. if the previous command did
           % not fail), do not keep or print it,
           if (~isempty(LastError))
              % If the error message is taken from the driver object, do NOT
              % update the driver object.
              if (~strcmp(MountObj.MouHn.lastError, LastError))
                 MountObj.MouHn.LastError = LastError;
              end
              MountObj.LogFile.writeLog(LastError)
              if MountObj.Verbose, fprintf('%s\n', LastError); end
           end
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
