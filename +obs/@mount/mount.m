classdef mount <handle

    properties (Dependent)
        RA
        Dec
        Az
        Alt
        TrackingSpeed
    end
      
    properties(GetAccess=public, SetAccess=private)
        Status = 'unknown';
        isEastOfPier = NaN;
    end

    properties(Hidden)
        MountDriverHndl = NaN;
        Port = '';
        MountName = NaN;
        GeoName = NaN;
        Log = '';
        
        MountPos=[NaN,NaN,NaN];
        MountCoo = struct('ObsLon',NaN,'ObsLat',NaN,'ObsHeight',NaN);
        TimeFromGPS
        ParkPos = [180,-30]; % park pos in [Az,Alt] (negative Alt is probably impossible)
        MinAlt = 15;
        preferEastOfPier = true; % TO IMPLEMENT
        flipPH=[92,92]; % ??? how to implement?
        isCounterWeightDown=true; % Test that this works as expected
        MeridianFlip=true; % if false, stop at the meridian limit
        MeridianLimit=92; % Test that this works as expected, no idea what happens
        
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
            MountObj.MountName = '1';
            MountObj.GeoName = [30, 30];
            MountObj.Log = '???';

        end
        
        function delete(MountObj)
            MountObj.MountDriverHndl.delete;
            fclose(MountObj);
            % shall we try-catch and report success/failure?
        end
        
    end
    
    methods
        % setters and getters
        function Az=get.Az(MountObj)
            Az = MountObj.MountDriverHndl.Az;
        end

        function set.Az(MountObj,Az)
            MountObj.MountDriverHndl.Az = Az;
            switch MountObj.MountDriverHndl.lastError
                case "target Az beyond limits"
                    MountObj.lastError = "target Az beyond limits";
            end            
        end
        
        function Alt=get.Alt(MountObj)
            Alt = MountObj.MountDriverHndl.Alt;
        end
        
        function set.Alt(MountObj,Alt)
            if (Alt >= MountObj.MinAlt)
               MountObj.MountDriverHndl.Alt = Alt;
               switch MountObj.MountDriverHndl.lastError
                   case "target Alt beyond limits"
                       MountObj.lastError = "target Alt beyond limits";
               end            
            else
               MountObj.lastError = "target Alt beyond limits";
            end
        end
        
        function RA=get.RA(MountObj)
            RA = MountObj.MountDriverHndl.RA;
        end

        function set.RA(MountObj,RA)
           [Az, Alt] = celestial.coo.convert_coo(RA, MountObj.Dec, 'j2000.0', 'h', +celestial.time.julday, [MountObj.MountCoo.ObsLon MountObj.MountCoo.ObsLat]./180.*pi)
           if(Alt < MountObj.MinAlt)
              fprintf('Target is too low\n')
              MountObj.lastError = 'Target is too low\n';
           else
              MountObj.MountDriverHndl.RA = RA;
              switch MountObj.MountDriverHndl.lastError
                 case "target Alt beyond limits"
                    MountObj.lastError = "target RA beyond limits";
              end
           end
        end

        function Dec=get.Dec(MountObj)
            Dec = MountObj.MountDriverHndl.Dec;
        end
        
        function set.Dec(MountObj,Dec)
           [Az, Alt] = celestial.coo.convert_coo(MountObj.RA, Dec, 'j2000.0', 'h', +celestial.time.julday, [MountObj.MountCoo.ObsLon MountObj.MountCoo.ObsLat]./180.*pi)
           if(Alt < MountObj.MinAlt)
              fprintf('Target is too low\n')
              MountObj.lastError = 'Target is too low\n';
           else
              MountObj.MountDriverHndl.Dec = Dec;
              switch MountObj.MountDriverHndl.lastError
                  case "target Alt beyond limits"
                      MountObj.lastError = "target Dec beyond limits";
              end
           end
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
            if (strcmp(Speed,'Sidereal')),
               Speed=MountObj.SiderealRate;
            end
            MountObj.lastError = ''
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
            MinAlt = MountObj.MountDriverHndl.MinAlt
        end
        
        function set.MinAlt(MountObj,MinAlt)
            MountObj.MountDriverHndl.MinAlt = MinAlt;
            switch MountObj.MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
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