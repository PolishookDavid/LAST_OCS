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
        isEastOfPier
    end

    properties(Hidden)
        MountDriverHndl = NaN;
        Port = '';
        MountName = '';
        GeoName = '';
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
        function MountObj=Mount(MountName, GeoName)
            % Open a driver object for the mount
            MountObj.MountDriverHndl=iOptronCEM120();

            % Update mount details
            MountObj.Port = MountObj.MountDriverHndl.Port;
            MountObj.MountName = MountName;
            MountObj.GeoName = GeoName;
            MountObj.Log = '???';

        end
        
        function delete(MountHndl)
            delete(MountHndl.serial_resource)
            % shall we try-catch and report success/failure?
        end
        
    end
    
    methods
        % setters and getters
        function Az=get.Az(MountObj)
            MountObj.Az = MountDriverHndl.get.Az;
        end

        function set.Az(MountObj,Az)
            MountDriverHndl.set.Az(Az);
            switch MountDriverHndl.lastError
                case "target Az beyond limits"
                    MountObj.lastError = "target Az beyond limits";
            end            
        end
        
        function EastOfPier=get.isEastOfPier(MountObj)
            % true if east, false if west.
            %  Assuming that the mount is polar aligned
            MountObj.isEastOfPier = MountDriverHndl.get.isEastOfPier;
        end

        function CounterweightDown=get.isCounterWeightDown(MountObj)
            MountObj.isCounterweightDown = MountDriverHndl.get.isCounterweightDown;
        end
        
        function Alt=get.Alt(MountObj)
            MountObj.Alt = MountDriverHndl.get.Alt;
        end
        
        function set.Alt(MountObj,Alt)
            MountDriverHndl.set.Alt(Alt);
            switch MountDriverHndl.lastError
                case "target Alt beyond limits"
                    MountObj.lastError = "target Alt beyond limits";
            end            
        end
        
        function Dec=get.Dec(MountObj)
            MountObj.Dec = MountHndl.get.Dec;
        end
        
        function set.Dec(MountObj,Dec)
            MountDriverHndl.set.Dec(Dec);
            switch MountDriverHndl.lastError
                case "target Alt beyond limits"
                    MountObj.lastError = "target Dec beyond limits";
            end            
        end
        
        function RA=get.RA(MountObj)
            MountObj.RA = MountDriverHndl.get.RA;
        end
        
 
        function set.RA(MountObj,RA)
            MountDriverHndl.set.RA(RA);
            switch MountDriverHndl.lastError
                case "target Alt beyond limits"
                    MountObj.lastError = "target RA beyond limits";
            end
        end

        function HourAngle=get.HA(MountObj)
            % Functionality from MAAT library
            % Get JD from the computer
            JD = celestial.time.julday;    
            LST = celestial.time.lst(JD,MountObj.MountCoo.ObsLon./RAD,'a');  % fraction of day

            MountObj.HA = LST - MountObj.RA;
        end
        
        
        function S=get.fullStatus(MountObj)
            S = MountDriverHndl.get.fullStatus;
        end
        
        function flag=get.TimeFromGPS(MountObj)
            flag=MountDriverHndl.get.TimeFromGPS;
        end
        
        function S=get.Status(MountObj)
            % Status of the mount: idle, slewing, park, home, tracking, unknown
            S = MountDriverHndl.get.Status;
        end
        
        % tracking implemented by setting the property TrackingSpeed.
        %  using custom tracking mode, which allows the broadest range
        
        function TrackSpeed=get.TrackingSpeed(MountObj)
            TrackSpeed = MountDriverHndl.get.TrackingSpeed;
        end

        function set.TrackingSpeed(TrackingSpeed,Speed)
            MountObj.lastError = ''
            MountDriverHndl.set.TrackingSpeed(Speed)
            MountObj.lastError = MountDriverHndl.lastError;
        end

% functioning parameters getters/setters & misc
        
        function flip=get.MeridianFlip(MountObj)
            flip = MountDriverHndl.get.MeridianFlip;
        end
        
        function set.MeridianFlip(MountObj,flip)
            MountDriverHndl.set.MeridianFlip(flip);
            switch MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
            end
        end

        function limit=get.MeridianLimit(MountObj)
            limit = MountDriverHndl.get.MeridianLimit;
        end
        
        function set.MeridianLimit(MountObj,limit)
            MountDriverHndl.set.MeridianLimit(limit);
            switch MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
            end
        end
        
        function MinAlt=get.MinAlt(MountObj)
            MinAlt = MountObj.MountDriverHndl.get.MinAlt
        end
        
        function set.MinAlt(MountObj,MinAlt)
            MountObj.MountDriverHndl.set.MinAlt(MinAlt)
            switch MountDriverHndl.lastError
                case "failed"
                    MountObj.lastError = "failed";
            end
        end
       
        function ParkPos=get.ParkPos(MountObj)
            ParkPosition = MountObj.MountDriverHndl.get.ParkPos
        end

        function set.ParkPos(MountObj,pos)
            MountObj.MountHndl.set.ParkPos(pos)
            switch MountDriverHndl.lastError
                case "invalid parking position"
                    MountObj.lastError = "invalid parking position";
            end
        end
        
        function pos=get.MountPos(MountObj)
            MountPosition = MountObj.MountDriverHndl.get.MountPos
        end
            
        function set.MountPos(MountObj,Position)
            MountObj.MountHndl.set.MountPos(Position)
            switch MountDriverHndl.lastError
                case "invalid position for mount"
                    MountObj.lastError = "invalid position for mount";
            end

        end

    end

end