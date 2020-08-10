classdef focuser <handle
    
    properties
        Pos=NaN;
    end
    
    properties (GetAccess=public, SetAccess=private)
        Status='unknown';
        LastPos=NaN;
    end
        
    properties (SetAccess=public, GetAccess=private)
%        RelPos=NaN;
        FocType       = NaN;
        FocUniqueName = NaN;
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
        LastError='';
        Limits=[NaN,NaN];
    end

    
    methods
        % constructor and destructor
        function Foc=focuser(varargin)

           DirName = obs.util.config.constructDirName('log');
           cd(DirName);

           % Opens Log for the camera
           Foc.LogFile = logFile;
           Foc.LogFile.Dir = DirName;
           Foc.LogFile.FileNameTemplate = 'LAST_%s.log';
           Foc.LogFile.logOwner = sprintf('%s.%s.%s_%s_Foc', ...
                                  obs.util.config.readSystemConfigFile('ObservatoryNode'), obs.util.config.readSystemConfigFile('MountGeoName'), obs.util.config.readSystemConfigFile('CamGeoName'), DirName(end-7:end));

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
               Foc.LastError = "could not read focuser position. Focuser disconnected. *Connect or Check Cables*";
            else
               focus = Foc.FocHn.Pos;
               Foc.LastError = Foc.FocHn.lastError;
            end
        end

        function set.Pos(Foc,focus)
            Foc.LogFile.writeLog(sprintf('call set.Pos. focus=%d',focus))

            Foc.LastPos = Foc.FocHn.LastPos;
            Foc.FocHn.Pos = focus;

            % Start timer to wait for focus to reach destination
            Foc.FocusMotionTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'focuser-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @Foc.callback_timer, 'ErrorFcn', 'beep');
            start(Foc.FocusMotionTimer);
            Foc.LogFile.writeLog('Start focuser timer')            
            
            Foc.LastError = Foc.FocHn.lastError;
        end
        
        % DOES NOT WORK !!! DP June 4, 2020
%         function set.RelPos(Foc,incr)
%             Foc.FocHn.RelPos(incr)
%             Foc.LogFile.writeLog(sprintf('call set.RelPos. focues increase=%d',incr))
%             Foc.LastError = Foc.FocHn.lastError;
%         end
        
        function focus=get.LastPos(Foc)
            focus = Foc.FocHn.LastPos;
            Foc.LastError = Foc.FocHn.lastError;
        end

        function Limits=get.Limits(Foc)
            Limits = Foc.FocHn.limits;
        end

        function s=get.Status(Foc)
            s = Foc.FocHn.Status;
            Foc.LastError = Foc.FocHn.lastError;
        end
        
        % Get the last error reported by the driver code
        function LastError=get.LastError(Foc)
            LastError = Foc.FocHn.lastError;
            Foc.LogFile.writeLog(LastError)
            if Foc.Verbose, fprintf('%s\n', LastError); end
        end

        % Set an error, update log and print to command line
        function set.LastError(Foc,LastError)
           % If the LastError is empty (e.g. if the previous command did
           % not fail), do not keep or print it,
           if (~isempty(LastError))
              % If the error message is taken from the driver object, do NOT
              % update the driver object.
              if (~strcmp(Foc.FocHn.lastError, LastError))
                 Foc.FocHn.lastError = LastError;
              end
              Foc.LogFile.writeLog(LastError)
              if Foc.Verbose, fprintf('%s\n', LastError); end
           end
        end

    end
end
