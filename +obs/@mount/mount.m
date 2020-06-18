classdef mount <handle

    properties (Dependent)
        RA   % Deg
        Dec  % Deg
        Az   % Deg
        Alt  % Deg
        TrackingSpeed
    end
      
    properties(GetAccess=public, SetAccess=private)
        MountType = NaN;
        MountModel = NaN;
        MountUniqueName = NaN;
        MountGeoName = NaN;
        TelescopeEastUniqueName = NaN;
        TelescopeWestUniqueName = NaN;
        isEastOfPier = NaN;
        Status = 'unknown';
    end

    properties(Hidden)
        MouHn;
        LogFile;
        
        MountPos=[NaN,NaN,NaN];
        MountCoo = struct('ObsLon',NaN,'ObsLat',NaN,'ObsHeight',NaN);
        TimeFromGPS = 0; % default is no, take time and coordinates from computer
        ParkPos = [NaN,NaN]; % park pos in [Az,Alt] (negative Alt is impossible)
        MinAlt = 15;
        MinAltPrev = NaN;
        MinAzAltMap = NaN;
        preferEastOfPier = true; % TO IMPLEMENT
        flipPH=[92,92]; % ??? how to implement?
        isCounterWeightDown=true; % Test that this works as expected
        MeridianFlip=true; % if false, stop at the meridian limit
        MeridianLimit=92; % Test that this works as expected, no idea what happens
        
        SlewingTimer;
        DistortionFile = '';
        SafetyTimer = NaN; % ???
    end
    
    % non-API-demanded properties, Enrico's judgement
    properties (Hidden) 
        Verbose = true; % for stdin debugging
        serial_resource % the serial object corresponding to Port
    end
    
    properties (Hidden, GetAccess=public, SetAccess=private, Transient)
        fullStatus % complete status as returned by the mount, including time, track, etc.
        lastError='';
    end
    
    properties(Hidden,Constant)
        SiderealRate=360/86164.0905; %sidereal tracking rate, degrees/sec
         % empirical slewing rate (fixed?), degrees/sec, excluding accelerations
         % if it could be varied (see ':GSR#'/':MSRn#'), this won't be a 
         % Constant property
        slewRate=2.5;
    end

    methods
        % constructor and destructor
        function MountObj=mount()
       
           DirName = util.constructDirName();
           cd(DirName);

           % Opens Log for the camera
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
%            fclose(MountObj);
            % shall we try-catch and report success/failure?
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
            Az = MountObj.MouHn.Az;
        end

        function set.Az(MountObj,Az)
            if (~strcmp(MountObj.Status, 'park'))
                  
               % Start timer to notify when slewing is complete
               MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
               start(MountObj.SlewingTimer);

               MountObj.MouHn.Az = Az;
               switch MountObj.MouHn.lastError
                   case "target Az beyond limits"
                       MountObj.lastError = "target Az beyond limits";
                       MountObj.LogFile.writeLog(MountObj.lastError)
                       if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
               end
            else
               MountObj.lastError = "Cannot slew, telescope is parking. Run: park(0)";
               MountObj.LogFile.writeLog(MountObj.lastError)
               if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
            end
        end
        
        function Alt=get.Alt(MountObj)
            Alt = MountObj.MouHn.Alt;
        end
        
        function set.Alt(MountObj,Alt)
            if (~strcmp(MountObj.Status, 'park'))
               if (Alt >= MountObj.MinAlt)
                  
                  % Start timer to notify when slewing is complete
                  MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
                  start(MountObj.SlewingTimer);

                  MountObj.MouHn.Alt = Alt;
                  switch MountObj.MouHn.lastError
                      case "target Alt beyond limits"
                          MountObj.lastError = "target Alt beyond limits";
                          MountObj.LogFile.writeLog(MountObj.lastError)
                          if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
                  end            
               else
                  MountObj.lastError = "target Alt beyond limits";
                  MountObj.LogFile.writeLog(MountObj.lastError)
                  if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
               end
            else
               MountObj.lastError = "Cannot slew, telescope is parking. Run: park(0)";
               MountObj.LogFile.writeLog(MountObj.lastError)
               if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
            end
        end
        
        function RA=get.RA(MountObj)
            RA = MountObj.MouHn.RA;
        end

        function set.RA(MountObj,RA)
           MountObj.goto(RA, MountObj.Dec)
        end

        function Dec=get.Dec(MountObj)
            Dec = MountObj.MouHn.Dec;
        end
        
        function set.Dec(MountObj,Dec)
           MountObj.goto(MountObj.RA, Dec)
        end
                
        function EastOfPier=get.isEastOfPier(MountObj)
            % true if east, false if west.
            %  Assuming that the mount is polar aligned
            EastOfPier = MountObj.MouHn.isEastOfPier;
        end

        function CounterWeightDown=get.isCounterWeightDown(MountObj)
            CounterWeightDown = MountObj.MouHn.isCounterweightDown;
        end
        
        function S=get.fullStatus(MountObj)
            S = MountObj.MouHn.fullStatus;
        end
        
        function flag=get.TimeFromGPS(MountObj)
            flag=MountObj.MouHn.TimeFromGPS;
        end
        
        function S=get.Status(MountObj)
            % Status of the mount: idle, slewing, park, home, tracking, unknown
            S = MountObj.MouHn.Status;
        end
        
        % tracking implemented by setting the property TrackingSpeed.
        %  using custom tracking mode, which allows the broadest range
        
        function TrackSpeed=get.TrackingSpeed(MountObj)
            TrackSpeed = MountObj.MouHn.TrackingSpeed;
        end

        function set.TrackingSpeed(MountObj,Speed)
            if (strcmp(Speed,'Sidereal'))
               Speed=MountObj.SiderealRate;
            end
            MountObj.lastError = '';
            MountObj.MouHn.TrackingSpeed = Speed;
            MountObj.lastError = MountObj.MouHn.lastError;
        end

% functioning parameters getters/setters & misc
        
        function flip=get.MeridianFlip(MountObj)
            flip = MountObj.MouHn.MeridianFlip;
        end
        
        function set.MeridianFlip(MountObj,flip)
            MountObj.MouHn.MeridianFlip = flip;
            switch MountObj.MouHn.lastError
                case "failed"
                    MountObj.lastError = "failed";
                    MountObj.LogFile.writeLog(MountObj.lastError)
                    if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
            end
        end

        function limit=get.MeridianLimit(MountObj)
            limit = MountObj.MouHn.MeridianLimit;
        end
        
        function set.MeridianLimit(MountObj,limit)
            MountObj.MouHn.MeridianLimit = limit;
            switch MountObj.MouHn.lastError
                case "failed"
                    MountObj.lastError = "failed";
                    MountObj.LogFile.writeLog(MountObj.lastError)
                    if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
            end
        end
        
        function MinAlt=get.MinAlt(MountObj)
            MinAlt = MountObj.MouHn.MinAlt;
        end
        
        function set.MinAlt(MountObj,MinAlt)
            MountObj.MouHn.MinAlt = MinAlt;
            switch MountObj.MouHn.lastError
                case "failed"
                    MountObj.lastError = "failed";
                    MountObj.LogFile.writeLog(MountObj.lastError)
                    if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
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
               fprintf('Format is 2-column table: Az, Alt\n')
               if MountObj.Verbose, fprintf('Format is 2-column table: Az, Alt\n'); end
            end
        end
       
        function ParkPosition=get.ParkPos(MountObj)
            ParkPosition = MountObj.MouHn.ParkPos;
        end

        function set.ParkPos(MountObj,pos)
            MountObj.MouHn.ParkPos = pos;
            switch MountObj.MouHn.lastError
                case "invalid parking position"
                    MountObj.lastError = "invalid parking position";
                    MountObj.LogFile.writeLog(MountObj.lastError)
                    if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
            end
        end
        
        function MountPosition=get.MountPos(MountObj)
            MountPosition = MountObj.MouHn.MountPos
        end
            
        function set.MountPos(MountObj,Position)
            MountObj.MouHn.MountPos = Position;
            switch MountObj.MouHn.lastError
                case "invalid position for mount"
                    MountObj.lastError = "invalid position for mount";
                    MountObj.LogFile.writeLog(MountObj.lastError)
                    if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
            end
        end
    end
end
