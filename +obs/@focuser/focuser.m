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
        Pos double     = NaN;
    end
    
    properties (GetAccess=public, SetAccess=private)
        Status char    = 'unknown';
        LastPos double = NaN;
    end
    
    properties (Hidden, GetAccess=public, SetAccess=private)
        IsConnected logical    = false;
    end
    
        
    properties (SetAccess=public, GetAccess=private)
        FocuserType       = NaN;
        FocuserUniqueName = NaN;
    end
        
    properties (Hidden=true)
        Handle;
        LogFile;
        PromptMirrorLock logical    = true;  % Prompt the user to check if mirror is locked
        Address                              % focuser address
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

    
    % constructor and destructor
    methods
        function Focuser=focuser(varargin)
            % Focuser constructor
            % Input  : * ..,key,val,...
            %            'PromptMirrorLock' - Default is true.
            %            'Config' - Config file name.
            % Output : - A focuser object
            
            InPar = inputParser;
            addOptional(InPar,'PromptMirrorLock',true);
            addOptional(InPar,'Config',[]);         % config file name
            addOptional(InPar,'ConfigStruct',struct());   % ConfigStruct
            parse(InPar,varargin{:});
            InPar = InPar.Results;
            
            Focuser.PromptMirrorLock = InPar.PromptMirrorLock;
            Focuser.Config           = InPar.Config;
            
            if Focuser.PromptMirrorLock
                fprintf('Release the mirror of the telescope using the two black nobs at the bottom!!!\n');
                Answer = input('Is the mirror unlocked? [y/n]\n', 's');
                switch lower(Answer)
                    case 'y'
                        % continue
                        Cont = true;
                    otherwise
                        fprintf('Will not continue when mirror is locked\n');
                        Cont = false;
                        delete(Focuser);
                end
            else
                Cont = true;
            end
            
            if Cont
                Focuser.Handle=inst.CelestronFocuser;
            end
             
        end
        
        function delete(Focuser)
            if(~isempty(Focuser.Handle))
               delete(Focuser.Handle)
            end
        end

    end

    %getters and setters
    methods
        function PosVal=get.Pos(Focuser)
            
            PosVal = Focuser.Handle.Pos;
            
            if Focuser.IsConnected
                % check for the case that the focuser is supposed to be
                % connected but it is not
                % In this case, reconnect

                if (isnan(PosVal))
                    Focser.connect(Focuser.Address);
                end
                PosVal = Focuser.Handle.Pos;
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
    
    methods
        function Success=connect(Obj,Address)
            % Connect to a focus motor
            % Input  : - A focuser object
            %          - Address: [1 1 1] or config file name with
            %            'config.focuser' substring or a port id.
            % Output : - A sucess flag.
            
            ConfigBaseName      = 'config.focuser';
            PhysicalPortKeyName = 'PhysicalPort';
            
            if nargin<2
                Address = [];
            end
            
            Obj.Address = Address;
            
            FocuserPort = [];
            LogOwner    = 'focuser';
            if isnumeric(Address)
                % user provided address of the form [Node, Mount, Camera]
                LogOwner = sprintf('focuser_%d_%d_%d',Address);
            else
                if ischar(Address)
                    if contains(Address(1:7),'config.')
                        % user provided a configuration file name
                        
                    else
                        % user provided a USB port name
                        FocuserPort = Address;
                        
                    end
                else
                    error('Unknown Address option');
                end
            end
            
            if isempty(FocuserPort)
                % read configuration file
                [ConfigStruct,ConfigFileName] = getConfigStruct(Obj,Address,ConfigBaseName,[]);
                
                Obj.ConfigStruct = ConfigStruct;
                Obj.Config       = ConfigFileName;
            end
            
            if Util.struct.isfield_notempty(Obj.ConfigStruct,PhysicalPortKeyName)
                FocuserPort         = Obj.ConfigStruct.(PhysicalPortKeyName);
                % convert the physical port name into port ID
                [IDpaths,PortList]  = serialDevPath;
                IndPort             = find(strcmp(FocuserPort,IDpaths));
                FocuserPort         = PortList(IndPort);
            end
            
            
            % generate a LogFile
            Obj.LogFile = logFile;
            Obj.LogFile.logOwner = LogOwner;
            if Util.struct.isfield_notempty(Obj.ConfigStruct,'LogFileDir')
                Obj.LogFile.Dir = Obj.ConfigStruct.LogFileDir;
            else
                warning('LogFileDir not appear in Config file');
                Obj.LogFile.writeLog('LogFileDir not appear in Config file');
            end
            
            
            if isempty(FocuserPort)
                Obj.LogFile.writeLog('Error: FocuserPort is empty');
            end
            
            % connect focuser
            
            Obj.Handle.connect(FocuserPort);
            if (isempty(Obj.Handle.LastError))
                Success = true;
                Focuser.IsConnected = true;
            else
                Success = false;
                Obj.LastError = Obj.Handle.LastError;
                Focuser.IsConnected = false;
            end

        end
        
        function disconnect(Obj)
            % disconnect focuser
            
            N = numel(Obj);
            for I=1:1:N
                Obj(I).Handle.disconnect;
                if ~isempty(Obj(I).LogFile)
                    Obj(I).LogFile.delete;
                end
            end
        end
        
    end
end
