classdef mount <handle

    properties
        RA  = NaN;
        Dec = NaN;
        HA  = NaN;
        Az  = NaN;
        Alt = NaN;
        TrackingSpeed=NaN;
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
        sidereal=360/86164.0905; %sidereal tracking rate, degrees/sec
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
            % shall we try-catch and report success/failure?
        end
        
    end
    
    methods
        % setters and getters
        function Az=get.Az(MountObj)
            MountObj.Az = MountObj.MountDriverHndl.Az;
        end

        function set.Az(MountObj,Az)
            MountObj.MountDriverHndl.Az(Az);
            switch MountObj.MountDriverHndl.lastError
                case "target Az beyond limits"
                    MountObj.lastError = "target Az beyond limits";
            end            
        end
        
        function isEastOfPier=get.isEastOfPier(MountObj)
            % true if east, false if west.
            %  Assuming that the mount is polar aligned
            MountObj.isEastOfPier = MountObj.MountDriverHndl.isEastOfPier;
        end

        function CounterweightDown=get.isCounterWeightDown(MountObj)
            MountObj.isCounterweightDown = MountObj.MountDriverHndl.isCounterweightDown;
        end
        
        function Alt=get.Alt(MountObj)
            MountObj.Alt = MountObj.MountDriverHndl.Alt;
        end
        
        function set.Alt(MountObj,Alt)
            MountObj.MountDriverHndl.Alt(Alt);
            switch MountObj.MountDriverHndl.lastError
                case "target Alt beyond limits"
                    MountObj.lastError = "target Alt beyond limits";
            end            
        end
        
        function Dec=get.Dec(MountObj)
            MountObj.Dec = MountObj.MountDriverHndl.Dec;
        end
        
        function set.Dec(MountObj,Dec)
            MountObj.MountDriverHndl.Dec(Dec);
            switch MountObj.MountDriverHndl.lastError
                case "target Alt beyond limits"
                    MountObj.lastError = "target Dec beyond limits";
            end            
        end
        
        function RA=get.RA(MountObj)
            MountObj.RA = MountObj.MountDriverHndl.RA;
        end
        
 
        function set.RA(MountObj,RA)
            MountObj.MountDriverHndl.RA(RA);
            switch MountObj.MountDriverHndl.lastError
                case "target Alt beyond limits"
                    MountObj.lastError = "target RA beyond limits";
            end
        end

        function HourAngle=get.HA(MountObj)
            % Functionality from MAAT library
            RAD = 180./pi;
            % Get JD from the computer
            JD = celestial.time.julday;    
            LST = celestial.time.lst(JD,MountObj.MountCoo.ObsLon./RAD,'a');  % fraction of day

            MountObj.HA = LST - MountObj.RA;
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

        function set.TrackingSpeed(TrackingSpeed,Speed)
            MountObj.lastError = ''
            MountObj.MountDriverHndl.TrackingSpeed(Speed)
            MountObj.lastError = MountObj.MountDriverHndl.lastError;
        end

% functioning parameters getters/setters & misc
        
        function flip=get.MeridianFlip(MountObj)
            flip = MountObj.MountDriverHndl.MeridianFlip;
        end
        
        function set.MeridianFlip(MountObj,flip)
            MountObj.MountDriverHndl.MeridianFlip(flip);
            switch MountObj.MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
            end
        end

        function limit=get.MeridianLimit(MountObj)
            limit = MountObj.MountDriverHndl.MeridianLimit;
        end
        
        function set.MeridianLimit(MountObj,limit)
            MountObj.MountDriverHndl.MeridianLimit(limit);
            switch MountObj.MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
            end
        end
        
        function MinAlt=get.MinAlt(MountObj)
            MinAlt = MountObj.MountDriverHndl.MinAlt
        end
        
        function set.MinAlt(MountObj,MinAlt)
            MountObj.MountDriverHndl.MinAlt(MinAlt)
            switch MountObj.MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
            end
        end
       
        function ParkPos=get.ParkPos(MountObj)
            ParkPosition = MountObj.MountDriverHndl.ParkPos
        end

        function set.ParkPos(MountObj,pos)
            MountObj.MountDriverHndl.ParkPos(pos)
            switch MountObj.MountDriverHndl.lastError
                case "invalid parking position"
                    MountObj.lastError = "invalid parking position";
            end
        end
        
        function pos=get.MountPos(MountObj)
            MountPosition = MountObj.MountDriverHndl.MountPos
        end
            
        function set.MountPos(MountObj,Position)
            MountObj.MountDriverHndl.MountPos(Position)
            switch MountObj.MountDriverHndl.lastError
                case "invalid position for mount"
                    MountObj.lastError = "invalid position for mount";
            end

        end

    end

end