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
        MountDriverHndl = NaN;
        Port = '';
        Log = '';
        
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
        verbose = true; % for stdin debugging
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

            % Open a driver object for the mount
            MountObj.MountDriverHndl=inst.iOptronCEM120();

            % Update mount details
            MountObj.Port = MountObj.MountDriverHndl.Port;
            MountObj.Log = '???';

        end
        
        function delete(MountObj)
            MountObj.MountDriverHndl.delete;
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
            Az = MountObj.MountDriverHndl.Az;
        end

        function set.Az(MountObj,Az)
            if (~strcmp(MountObj.Status, 'park'))
                  
               % Start timer to notify when slewing is complete
               MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
               start(MountObj.SlewingTimer);

               MountObj.MountDriverHndl.Az = Az;
               switch MountObj.MountDriverHndl.lastError
                   case "target Az beyond limits"
                       MountObj.lastError = "target Az beyond limits";
               end
            else
               MountObj.lastError = "Telescope is parking. Run: park(0)";
               fprintf('%s\n', MountObj.lastError)
            end
        end
        
        function Alt=get.Alt(MountObj)
            Alt = MountObj.MountDriverHndl.Alt;
        end
        
        function set.Alt(MountObj,Alt)
            if (~strcmp(MountObj.Status, 'park'))
               if (Alt >= MountObj.MinAlt)
                  
                  % Start timer to notify when slewing is complete
                  MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
                  start(MountObj.SlewingTimer);

                  MountObj.MountDriverHndl.Alt = Alt;
                  switch MountObj.MountDriverHndl.lastError
                      case "target Alt beyond limits"
                          MountObj.lastError = "target Alt beyond limits";
                  end            
               else
                  MountObj.lastError = "target Alt beyond limits";
                  fprintf('%s\n', MountObj.lastError)
               end
            else
               MountObj.lastError = "Telescope is parking. Run: park(0)";
               fprintf('%s\n', MountObj.lastError)
            end
        end
        
        function RA=get.RA(MountObj)
            RA = MountObj.MountDriverHndl.RA;
        end

        function set.RA(MountObj,RA)
           MountObj.goto(RA, MountObj.Dec)
        end

        function Dec=get.Dec(MountObj)
            Dec = MountObj.MountDriverHndl.Dec;
        end
        
        function set.Dec(MountObj,Dec)
           MountObj.goto(MountObj.RA, Dec)
        end
                
        function EastOfPier=get.isEastOfPier(MountObj)
            % true if east, false if west.
            %  Assuming that the mount is polar aligned
            EastOfPier = MountObj.MountDriverHndl.isEastOfPier;
        end

        function CounterWeightDown=get.isCounterWeightDown(MountObj)
            CounterWeightDown = MountObj.MountDriverHndl.isCounterweightDown;
        end
        
        function S=get.fullStatus(MountObj)
            S = MountObj.MountDriverHndl.fullStatus;
        end
        
        function flag=get.TimeFromGPS(MountObj)
            flag=MountObj.MountDriverHndl.TimeFromGPS;
        end
        
        function S=get.Status(MountObj)
            % Status of the mount: idle, slewing, park, home, tracking, unknown
            S = MountObj.MountDriverHndl.Status;
        end
        
        % tracking implemented by setting the property TrackingSpeed.
        %  using custom tracking mode, which allows the broadest range
        
        function TrackSpeed=get.TrackingSpeed(MountObj)
            TrackSpeed = MountObj.MountDriverHndl.TrackingSpeed;
        end

        function set.TrackingSpeed(MountObj,Speed)
            if (strcmp(Speed,'Sidereal'))
               Speed=MountObj.SiderealRate;
            end
            MountObj.lastError = '';
            MountObj.MountDriverHndl.TrackingSpeed = Speed;
            MountObj.lastError = MountObj.MountDriverHndl.lastError;
        end

% functioning parameters getters/setters & misc
        
        function flip=get.MeridianFlip(MountObj)
            flip = MountObj.MountDriverHndl.MeridianFlip;
        end
        
        function set.MeridianFlip(MountObj,flip)
            MountObj.MountDriverHndl.MeridianFlip = flip;
            switch MountObj.MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
            end
        end

        function limit=get.MeridianLimit(MountObj)
            limit = MountObj.MountDriverHndl.MeridianLimit;
        end
        
        function set.MeridianLimit(MountObj,limit)
            MountObj.MountDriverHndl.MeridianLimit = limit;
            switch MountObj.MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
            end
        end
        
        function MinAlt=get.MinAlt(MountObj)
            MinAlt = MountObj.MountDriverHndl.MinAlt;
        end
        
        function set.MinAlt(MountObj,MinAlt)
            MountObj.MountDriverHndl.MinAlt = MinAlt;
            switch MountObj.MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
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
            end
        end
       
        function ParkPosition=get.ParkPos(MountObj)
            ParkPosition = MountObj.MountDriverHndl.ParkPos;
        end

        function set.ParkPos(MountObj,pos)
            MountObj.MountDriverHndl.ParkPos = pos;
            switch MountObj.MountDriverHndl.lastError
                case "invalid parking position"
                    MountObj.lastError = "invalid parking position";
            end
        end
        
        function MountPosition=get.MountPos(MountObj)
            MountPosition = MountObj.MountDriverHndl.MountPos
        end
            
        function set.MountPos(MountObj,Position)
            MountObj.MountDriverHndl.MountPos = Position;
            switch MountObj.MountDriverHndl.lastError
                case "invalid position for mount"
                    MountObj.lastError = "invalid position for mount";
            end

        end

    end

end