% Focuser control handle class (for Celestron's focusers) 
% Package: +obs
% Description: operate focuser drivers.
%              Currently can work with Celestron's focusers
% Input  : Focuser text, e.g. 'Robot'.
% Output : A focuser class
%     By :
% Example: F = obs.focuser;
%          F = obs.focuser('Robot');    % Will skip lock-question
%
% Settings properties and methods:
%       F.Pos = 20000;        % Move the absolute value to 20000;
%       F.relPos(-100);       % Move 100 steps inword from current location.
%       F.Handle;             % Direct excess to the driver object
%
% More values to get:
%       F.Status              % Presents working status of focuser
%       F.Limits              % Presents defined limits of the focuser movement
%       F.waitFinish;         % Wait for fociser status to be Idle
%
% Author: David Polishook, Mar 2020
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
classdef focuser <obs.LAST_Handle
    
    properties
        Pos=NaN;
    end
    
    properties (GetAccess=public, SetAccess=private)
        Status='unknown';
        LastPos=NaN;
    end
        
    properties (SetAccess=public, GetAccess=private)
%        RelPos=NaN;
        FocuserType       = NaN;
        FocuserUniqueName = NaN;
    end
        
    properties (Hidden=true)
        Handle;
        LogFile;
    end

    % non-API-demanded properties, Enrico's judgement
    properties (Hidden=true) 
        Verbose=true; % for stdin debugging
        SerialResource % the serial object corresponding to Port
    end
    
    properties (Hidden=true, GetAccess=public, SetAccess=private, Transient)
        FocusMotionTimer;
        LastError='';
        Limits=[NaN,NaN];
    end

    
    methods
        % constructor and destructor
        function Focuser=focuser(varargin)

           if (isempty(varargin))
              Answer = input('Is the mirror unlocked? [y/n]\n', 's');
              if strcmpi(Answer,'y')
                 Focuser.Handle=inst.CelestronFocuser;
              else
                 if Focuser.Verbose, fprintf('Release the mirror of the telescope using the two black nobs at the bottom!!!\n'); end
%                 Focuser.LogFile.writeLog('Release the mirror of the telescope using the two black nobs at the bottom!!!')
                 delete(Focuser);
              end
           else
              switch varargin{1}
                 case 'Robot'
                    % The robot assumes the mirror of the telescope is
                    % unlocked, thus the focuser can move.
                    Focuser.Handle=inst.CelestronFocuser;
              end
           end
           % Connecting to port in a separate method
        end
        
        function delete(Focuser)
            if(~isempty(Focuser.Handle))
               delete(Focuser.Handle)
            end
        end

    end

    methods
        %getters and setters
        function focus=get.Pos(Focuser)
            if (isnan(Focuser.Handle.Pos))
               focus = NaN;
               Focuser.LastError = "could not read focuser position. Focuser disconnected. *Connect or Check Cables*";
            else
               focus = Focuser.Handle.Pos;
               Focuser.LastError = Focuser.Handle.LastError;
            end
        end

        function set.Pos(Focuser,focus)
            Focuser.LogFile.writeLog(sprintf('call set.Pos. focus=%d',focus))

            Focuser.LastPos = Focuser.Handle.LastPos;
            Focuser.Handle.Pos = focus;

            % Start timer to wait for focus to reach destination
            Focuser.FocusMotionTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'focuser-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @Focuser.callback_timer, 'ErrorFcn', 'beep');
            start(Focuser.FocusMotionTimer);
            Focuser.LogFile.writeLog('Start focuser timer')            
            
            Focuser.LastError = Focuser.Handle.LastError;
        end
        
        % DOES NOT WORK !!! DP June 4, 2020
%         function set.RelPos(Focuser,incr)
%             Focuser.Handle.RelPos(incr)
%             Focuser.LogFile.writeLog(sprintf('call set.RelPos. focues increase=%d',incr))
%             Focuser.LastError = Focuser.Handle.LastError;
%         end
        
        function focus=get.LastPos(Focuser)
            focus = Focuser.Handle.LastPos;
            Focuser.LastError = Focuser.Handle.LastError;
        end

        function Limits=get.Limits(Focuser)
            Limits = Focuser.Handle.Limits;
        end

        function s=get.Status(Focuser)
            s = Focuser.Handle.Status;
            Focuser.LastError = Focuser.Handle.LastError;
        end
        
        % Get the last error reported by the driver code
        function LastError=get.LastError(Focuser)
            LastError = Focuser.Handle.LastError;
            Focuser.LogFile.writeLog(LastError)
            if Focuser.Verbose, fprintf('%s\n', LastError); end
        end

        % Set an error, update log and print to command line
        function set.LastError(Focuser,LastError)
           % If the LastError is empty (e.g. if the previous command did
           % not fail), do not keep or print it,
           if (~isempty(LastError))
              % If the error message is taken from the driver object, do NOT
              % update the driver object.
%              if (~strcmp(Focuser.Handle.LastError, LastError))
%                 Focuser.Handle.LastError = LastError;
%              end
              Focuser.LogFile.writeLog(LastError)
              if Focuser.Verbose, fprintf('%s\n', LastError); end
           end
        end

    end
end
