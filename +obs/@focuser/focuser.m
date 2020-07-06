classdef focuser <handle
    
    properties
        Pos=NaN;
    end
    
    properties (GetAccess=public, SetAccess=private)
        Status='unknown';
        LastPos=NaN;
        FocType       = NaN;
        FocUniqueName = NaN;
    end
        
    properties (SetAccess=public, GetAccess=private)
%        RelPos=NaN;
    end
        
    properties (Hidden=true)
        FocHn;
        LogFile;
    end

    % non-API-demanded properties, Enrico's judgement
    properties (Hidden=true) 
        Verbose=true; % for stdin debugging
        serial_resource % the serial object corresponding to Port
    end
    
    properties (Hidden=true, GetAccess=public, SetAccess=private, Transient)
        FocusMotionTimer;
        lastError='';
        limits=[NaN,NaN];
    end

    
    methods
        % constructor and destructor
        function Foc=focuser(varargin)

           DirName = util.constructDirName('log');
           cd(DirName);

           % Opens Log for the camera
           Foc.LogFile = logFile;
           Foc.LogFile.Dir = DirName;
           Foc.LogFile.FileNameTemplate = 'LAST_%s.log';
           Foc.LogFile.logOwner = sprintf('%s.%s.%s_%s_Foc', ...
                                  util.readSystemConfigFile('ObservatoryNode'), util.readSystemConfigFile('MountGeoName'), util.readSystemConfigFile('CamGeoName'), DirName(end-7:end));

           if (isempty(varargin))
              Answer = input('Is the mirror unlock? [y/n]\n', 's');
              if strcmpi(Answer,'y')
                 Foc.FocHn=inst.CelestronFocuser;
              else
                 if Foc.Verbose, fprintf('Release the mirror of the telescope using the two black nobs at the bottom!!!\n'); end
                 Foc.LogFile.writeLog('Release the mirror of the telescope using the two black nobs at the bottom!!!')
                 delete(Foc);
              end
           else
              switch varargin{1}
                 case 'Robot'
                    % The robot assumes the mirror of the telescope is
                    % unlocked, thus the focuser can move.
                    Foc.FocHn=inst.CelestronFocuser;
              end
           end
           % Connecting to port in a separate method
        end
        
        function delete(Foc)
            if(~isempty(Foc.FocHn))
               delete(Foc.FocHn)
            end
        end

    end

    methods
        %getters and setters
        function focus=get.Pos(Foc)
            if (isnan(Foc.FocHn.Pos))
               Foc.lastError = "could not read focuser position. Focuser disconnected. *Connect or Check Cables*";
               if Foc.Verbose, fprintf('%s\n', Foc.lastError); end
               Foc.LogFile.writeLog(Foc.lastError)
            else
               focus = Foc.FocHn.Pos;
               switch Foc.FocHn.lastError
                  case "could not read focuser position"
                     Foc.lastError = "could not read focuser position. Focuser disconnected. *Connect or Check Cables*";
                     if Foc.Verbose, fprintf('%s\n', Foc.lastError); end
                     Foc.LogFile.writeLog(Foc.lastError)
               end
            end
        end

        function set.Pos(Foc,focus)
            Foc.LastPos = Foc.FocHn.LastPos;
            Foc.FocHn.Pos = focus;

            % Start timer to wait for focus to reach destination
            Foc.FocusMotionTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'focuser-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @Foc.callback_timer, 'ErrorFcn', 'beep');
            start(Foc.FocusMotionTimer);
            Foc.LogFile.writeLog('Start focuser timer')            
            
            Foc.LogFile.writeLog(sprintf('call set.Pos. focus=%d',focus))
            switch Foc.FocHn.lastError
                case "set new focus position failed"
                    Foc.lastError = "set new focus position failed";
                    if Foc.Verbose, fprintf('%s\n', Foc.lastError); end
                    Foc.LogFile.writeLog(Foc.lastError)
                case "Focuser commanded to move out of range!"
                    Foc.lastError = "Focuser commanded to move out of range!";
                    if Foc.Verbose, fprintf('%s\n', Foc.lastError); end
                    Foc.LogFile.writeLog(Foc.lastError)
            end       
        end
        
        % DOES NOT WORK !!! DP June 4, 2020
%         function set.RelPos(Foc,incr)
%             Foc.FocHn.RelPos(incr)
%             Foc.LogFile.writeLog(sprintf('call set.RelPos. focues increase=%d',incr))
%             switch Foc.FocHn.lastError
%                 case "set new focus position failed"
%                     Foc.lastError = "set new focus position failed";
%                     if Foc.Verbose, fprintf('%s\n', Foc.lastError); end
%                     Foc.LogFile.writeLog(Foc.lastError)
%
%                 case "Focuser commanded to move out of range!"
%                     Foc.lastError = "Focuser commanded to move out of range!";
%                     if Foc.Verbose, fprintf('%s\n', Foc.lastError); end
%                     Foc.LogFile.writeLog(Foc.lastError)
%             end
%         end
        
        function focus=get.LastPos(Foc)
            focus = Foc.FocHn.LastPos;
            switch Foc.FocHn.lastError
                case "could not read focuser position"
                    Foc.lastError = "could not read focuser position";
                    if Foc.Verbose, fprintf('%s\n', Foc.lastError); end
                    Foc.LogFile.writeLog(Foc.lastError)
            end
        end

        function limits=get.limits(Foc)
            limits = Foc.FocHn.limits;
        end
        
        function s=get.Status(Foc)
            s = Foc.FocHn.Status;
            switch Foc.FocHn.lastError
                case "could not get status, communication problem?"
                    Foc.lastError = "could not get status, communication problem?";
                     if Foc.Verbose, fprintf('%s\n', Foc.lastError); end
                    Foc.LogFile.writeLog(Foc.lastError)
           end            
        end
        
    end
end
