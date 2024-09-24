% Mount control superclass
% Package: +obs/@mount
% Description: operate mount drivers.
%
% Author: Enrico Segre, Jun 2021
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

classdef mount < inst.device

    properties (GetAccess=public, SetAccess=private)
        LST double % Local Sidereal Time (LST) in [deg] (fraction of day)
    end
    
    properties(Hidden)
        LogFile            = LogFile;
        LogFileDir char    = '';
    end
    
    % Mount ID
    properties(Hidden=true)
        ObsLon(1,1) double      = NaN;
        ObsLat(1,1) double      = NaN;
        ObsHeight(1,1) double   = NaN;
        PointingModel obs.pointingModel;
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
        TimeFromGPS logical     = false;      
    end

    % solar system ephemerides. It is somewhat dirty to have it as a mount
    % property, but we have no better solution for now. Loading it is done
    % in the constructor, to catch the case when it is not installed
    properties (Hidden)
        INPOP
    end
        
    properties (Hidden=true, GetAccess=public, SetAccess=private, Transient)
        Ready=struct('flag',true,'reason',''); % if and why the mount can be operated
    end
    
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

            % call the parent creator to define the property listeners
            MountObj=MountObj@inst.device;

            if exist('id','var') && ~isempty(id)
                MountObj.Id=id;
            end
            % load configuration
            MountObj.loadConfig(MountObj.configFileName('createsuper'))
            if ~isempty(MountObj.Id)
                MountObj.PointingModel=obs.pointingModel(MountObj.Id);
            end
            % pass geographical coordinates to the driver
            if ~isempty(MountObj.Config) && ...
               ~isempty(MountObj.Config.ObsLat) && ...
               ~isempty(MountObj.Config.ObsLon) && ...
               ~isempty(MountObj.Config.ObsHeight)
                MountObj.MountPos=[MountObj.Config.ObsLat,...
                                   MountObj.Config.ObsLon,...
                                   MountObj.Config.ObsHeight];
            end
            
            % load the ephemerides, if installed. Takes ~10sec
            try
                MountObj.INPOP = celestial.INPOP.init({'Ear'},'MaxOrder',5);
            catch
                MountObj.reportError('the INPOP ephemerides were not found, doing without')
            end

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
            
            % create periodical queries to push stati to PV
            MountObj.PeriodicQueries(1).Properties={'getPropertyIfConnected(''Alt'')',...
                'getPropertyIfConnected(''Status'')'};
            MountObj.PeriodicQueries(1).Period=10;
            MountObj.PushPropertyChanges = true;

        end
        
        function delete(MountObj)
            % delete mount object and related sub objects (if they were
            % defined) (formely: Handle, SlewingTimer - all making no
            %  sense)
            MountObj.PushPropertyChanges=false; % to delete timers
            try
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

    % getter for isReady
        function r=get.Ready(M)
            r=struct('flag',false,'reason',M.Status);
            switch r.reason
                case {'disabled','idle','tracking'}
                    r.flag=true;
            end
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
