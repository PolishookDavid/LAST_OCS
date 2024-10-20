classdef superunit < obs.LAST_Handle
    % Spawned matlab sessions object, including messengers for dual
    % communication
    % Some conventions are tacitly assumed to be enforced throughout the
    %  codebase: unitCS objects in the sessions are always called 'Unit',
    %  have always a property Unit.AbortActivity which can be set to true
    %  asynchronously in order to abort long operations, and so on

    properties
        UnitHosts  cell % list of hosts on which to spawn units (cell of char arrays)
        UnitTerminal char ='none'; % for all spawns, can be overriden individually
        SlaveTerminals char ='none'; % ditto
        RemoteUnits obs.util.SpawnedMatlab; % array of SpawnedMatlabs;
        Logging logical =false; % create stdout and stderr log files. Must be set BEFORE connect
        LoggingDir char ; % directory where to log. Must be set BEFORE connect
    end
    
    methods
        % constructor and destructor
        function S=superunit(id)
            % creates the object, assigning an Id if provided, and loads
            %  the configuration. The actual spawning is done by the method
            %  .connect
            if ~exist('id','var')
                id='';
            end
            if ~isempty(id)
                S.Id=id;
            end
            % load configuration
            S.loadConfig(S.configFileName('create'))
        end
        
        function delete(S)
            % maybe not needed, the destructor of SpawnedMatlab should do
            % Or maybe, we should find a way so that the spawned sessions
            %  are NOT destroyed
            for i=1:numel(S.RemoteUnits)
                % S.RemoteUnits(i).disconnect;
            end
        end
        
    end


    methods
        % setters of properties which need further propagation
        function set.UnitHosts(S,UnitHosts)
            % setter for UnitHosts, constructs all the .RemoteUnits
            S.UnitHosts=UnitHosts;
            Nunits=numel(UnitHosts);
            S.RemoteUnits=repmat(obs.util.SpawnedMatlab,1,Nunits);
            for i=1:Nunits
                id=S.hostUnitId(S.UnitHosts{i});
                S.RemoteUnits(i)=obs.util.SpawnedMatlab(sprintf('%02d_master',id));
                if ~isempty(id)
                    S.RemoteUnits(i).RemoteUser='ocs';
                end
                % set .RemoteUnit(i).Host. The method .spawn sets it
                %  explicitely, but .connect assumes that is is already set.
                S.RemoteUnits(i).Host=S.UnitHosts{i};
                S.RemoteUnits(i).RemoteTerminal=S.UnitTerminal;
                S.RemoteUnits(i).RemoteMessengerFlavor='listener';
                % this is needed to reconnect to already existing units,
                %  without attempting to spawn them
                S.RemoteUnits(i).MessengerRemotePort=11000;
                S.RemoteUnits(i).ResponderRemotePort=13000;
            end
        end
        
        function set.UnitTerminal(S,termtype)
            termtype=S.validTermType(termtype);
            for i=1:numel(S.RemoteUnits)
                S.RemoteUnits(i).RemoteTerminal=termtype;
            end
            S.UnitTerminal=termtype;
        end
        
        function set.SlaveTerminals(S,termtype)
            termtype=S.validTermType(termtype);
            S.SlaveTerminals=termtype;
        end
        
        function set.Logging(S,flag)
            for i=1:numel(S.RemoteUnits)
                S.RemoteUnits(i).Logging=flag;
            end
            S.Logging=flag;
        end
        
        function set.LoggingDir(S,path)
            for i=1:numel(S.RemoteUnits)
                S.RemoteUnits(i).LoggingDir=path;
            end
            S.LoggingDir=path;
        end
        
    end
    
    methods
        % connect and disconnect
        function spawn(S,units)
            % spawn includes connect
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            % first spawn serially all
            for i=units(:)'
                try
                    S.report('creating Master with Unit on %s\n',S.UnitHosts{i})
                    S.RemoteUnits(i).spawn(S.UnitHosts{i},...
                        [],S.RemoteUnits(i).MessengerRemotePort,...
                        [],S.RemoteUnits(i).ResponderRemotePort);
                catch
                    S.reportError('cannot create Unit on host %s',S.UnitHosts{i})
                end
            end
            % then try to connect
            for i=units(:)'
                id=S.hostUnitId(S.UnitHosts{i});
                S.report('connecting to spawned session "%s"\n',S.RemoteUnits(i).Id')
                if S.RemoteUnits(i).connect
                    S.send(sprintf('Unit=obs.unitCS(''%02d'');',id),i)
                    S.sendEnqueue(sprintf(...
                      'for i=1:numel(Unit.Slave),Unit.Slave(i).RemoteTerminal=''%s'';end',...
                      S.SlaveTerminals),i);
                else
                    S.reportError('cannot connect to the master created on host %s',...
                        S.UnitHosts{i})
                end
            end
        end
        
        function res=connect(S,units)
            % (re)connects to an already spawned remote unit
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            res=S.RemoteUnits(units).connect;
            % turn on periodic self updating of MessengerCommon.set.ExecutingCommand
            %  for MasterMessenger
            for i=1:numel(units)
                if res(i)
                    S.send('MasterMessenger.PushPropertyChanges=true',units(i));
                end
            end
         end
        
        function disconnect(S,units)
            % disconnect from remote units, without terminating them
            %  (the hardware stays on and the unit is available for another
            %   client to connect to it)
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            S.RemoteUnits(units).disconnect;
        end
        
        function terminate(S,units)
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            S.RemoteUnits(units).terminate;
        end
        
        % shortcuts for sending multiple commands
        function res=query(S,command,units)
            % query the same command to all or specific units
            %  input: command: char array
            %         units:   empty or numeric array
            %  note: this is serial, the next command is sent only after
            %  the previous reply has arrived
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            res=cell(1,numel(units));
            for i=1:numel(units)
                try
                    res{i}=S.RemoteUnits(units(i)).Messenger.query(command);
                catch
                    S.reportError('invalid Messenger for unit %s',S.RemoteUnits(units(i)).Id)
                end
            end
        end
        
        function send(S,command,units)
            % send the same command to all or specific units, without waiting
            %  for replies, but checking if they are busy
            %  input: command: char array
            %         units:   empty or numeric array
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            for i=1:numel(units)
                UId=S.RemoteUnits(units(i)).Id;
                try
%                    status=S.RemoteUnits(units(i)).Status;
%                    if ~any(strcmpi(status,{'disconnected','dead'}))
                        cexec=S.commandExecuting(units(i));
                        if isempty(cexec{:})
                            S.RemoteUnits(units(i)).Messenger.send(command);
                        else
                            S.report('Unit %s is currently executing "%s"\n',...
                                UId,cexec{:})
                            S.report(' the command "%s" won''t be sent\n',command)
                            S.report('You might want to use %s.sendEnqueue() instead, at your risk!\n',...
                                    inputname(1))
                        end
%                     else
%                         S.report('unit %s is %s and cannot accept commands\n',...
%                             S.RemoteUnits(UId,status))
%                     end
                 catch
                    S.reportError('invalid Messenger for unit %s',UId)
                end
            end
        end

        function sendEnqueue(S,command,units)
            % send the same command to all or specific units, without waiting
            %  for replies, and without checking if they are busy. If they
            %  are, the udp buffer acts as a sort of command queue, but its
            %  behavior is fragile - there is no control on what happens if
            %  the buffer overflows, and no way of flush the queue - the
            %  buffer could be flushed, but the associated callback queue not
            % Input: command: char array
            %         units:   empty or numeric array
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            for i=1:numel(units)
                try
                    S.RemoteUnits(units(i)).Messenger.send(command);
                catch
                    S.reportError('invalid Messenger for unit %s',S.RemoteUnits(units(i)).Id)
                end
            end
        end

        % Alternatively, sending multiple commands using the Responder,
        %  i.e. forcing a callback
        function res=queryCallback(S,command,units)
            % query the same command to all or specific units, using the
            % Responder messenger, which always does a callback
            %
            %  input: command: char array
            %         units:   empty or numeric array
            %  Notes:
            %  - this is serial, the next command is sent only after
            %    the previous reply has arrived
            %  - a query command which involves another callback may fail
            %    I.e., a query about Unit.Slave(i).Status
            %
            % Use case:
            %   S.send('GeneralStatus=''busy'';pause(20);GeneralStatus=''free'';')
            %   S.queryCallback('GeneralStatus')

            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            res=cell(1,numel(units));
            for i=1:numel(units)
                try
                    res{i}=S.RemoteUnits(units(i)).Responder.query(command);
                catch
                    S.reportError('invalid Responder for unit %s',S.RemoteUnits(units(i)).Id)
                end
            end
        end

        function sendCallback(S,command,units)
            % send the same command to all or specific units, without waiting
            %  for replies, using the Responder messenger, which always 
            %  does a callback
            %  input: command: char array
            %         units:   empty or numeric array
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            for i=1:numel(units)
                try
                    S.RemoteUnits(units(i)).Responder.send(command);
                catch
                    S.reportError('invalid Responder for unit %s',S.RemoteUnits(units(i)).Id)
                end
            end
        end
        
        function command=commandExecuting(S,units)
            % use the Responder to check with a callback if the unit is
            %  running a command sent via the Messenger, i.e. if it is busy
            %  with an interruptible command. An empty result means that
            %  the unit is free to receive listener commands (that however
            %  does not imply that the session is not busy with a command
            %  sent on the Responder, which is unfortunately
            %  uninterruptible)
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            command=S.queryCallback('MasterMessenger.ExecutingCommand',units);
        end
        
        % shotcuts to send specific Unit commands
        
        function success=abortActivity(S,units)
            % set via callback Unit.AbortActivity=true, so that long
            %  commands which take that property into account can abort
            %  (provided that they have been started either interactively
            %  at matlab prompt or evaluated by MasterMessenger, which is a
            %  Listener)
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            S.sendCallback('Unit.abort;',units);
            success=S.queryCallback('Unit.AbortActivity',units);
        end
        
        % shall we make also shortcuts for Unit.connect, Unit.shutdown, and
        %  other common operative activities? Instinctively I'd say not at
        %  this level, because they are at another level of specificity,
        %  and many have options. Or?
        
        function success=connectResponders(S,units)
            % a last resort for attempting to reconnect to problematic sessions,
            %  e.g. if they were created by another superunit process, and
            %  kept busy by some long command. Just connect won't work
            %  because it can't send commands via the busy Messenger
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            success=S.RemoteUnits(units).reconnectResponder;
        end
        
    end

    methods (Static)
        function id=hostUnitId(address)
            % quick and dirty function to determine the Unit.Id from
            %  either the static host name or ip in 10.23.1.x,
            % intended to be adequate for LAST
            id=sscanf(address,'last%d');
            if isempty(id)
                id=ceil(sscanf(address,'10.23.%d.%d')/2);
                if ~isempty(id)
                    id=id(end);
                else
                    % return 0 as last resort. This will spawn an Unit with Id=00,
                    %  better than nothing at least for testing on non LAST
                    %  hosts
                    id=0;
                end
            end
        end
        
        function valid=validTermType(termtype)
            % termtype can be abbreviated
            if isempty(termtype)
                termtype='none';
            end
            termoptions={'xterm','gnome-terminal','desktop','silentx','none'};
            q=contains(termoptions,lower(termtype));
            if ~any(q)
                q=numel(termoptions);
            end
            valid = termoptions{q};
        end
    end
end