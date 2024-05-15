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
            % maybe not needed, the destructor od SpawnedMatlab should do
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
                S.RemoteUnits(i)=obs.util.SpawnedMatlab(sprintf('master%02d',id));
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
            for i=1:numel(units)
                j=units(i);
                id=S.hostUnitId(S.UnitHosts{j});
                try
                    S.report('creating Master with Unit on %s\n',S.UnitHosts{j})
                    S.RemoteUnits(j).spawn(S.UnitHosts{j},[],11000,[],13000)
                catch
                    S.reportError('cannot create Unit on host %s',S.UnitHosts{j})
                end
            end
            % then try to connect
            for i=1:numel(units)
                j=units(i);
                id=S.hostUnitId(S.UnitHosts{j});
                S.report('connecting to spawned session "%s"\n',S.RemoteUnits(j).Id')
                if S.RemoteUnits(j).connect
                    S.send(sprintf('Unit=obs.unitCS(''%02d'');',id),j)
                    S.send(sprintf(...
                        'for i=1:numel(Unit.Slave),Unit.Slave(i).RemoteTerminal=''%s'';end',...
                        S.SlaveTerminals),j);
                else
                    S.reportError('cannot connect to the master created on host %s',...
                        S.UnitHosts{j})
                end
            end
        end
        
        function res=connect(S,units)
            % (re)connects to an already spawned remote unit
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            res=false(size(units));
            for i=1:numel(units)
                res(i)=S.RemoteUnits(units(i)).connect;
            end
         end
        
        function disconnect(S,units)
            % disconnect from remote units, without terminating them
            %  (the hardware stay on and the unit is available for another
            %   client to connect with it)
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            for i=1:numel(units)
                S.RemoteUnits(units(i)).disconnect;
            end
        end
        
        function terminate(S,units)
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            for i=1:numel(units)
                S.RemoteUnits(units(i)).terminate;
            end
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
            %  for replies
            %  input: command: char array
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
            % set via callabck Unit.AbortActivity=true, so that long
            %  commands which take that property into account can abort
            %  (provided that they have been started either interactively
            %  at matlab prompt or evaluated by MasterMessenger, which is a
            %  Listener)
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            S.sendCallback('Unit.AbortActivity=true;',units);
            success=S.queryCallback('Unit.AbortActivity',units);
        end
        
        % shall we make also shortcuts for Unit.connect, Unit.shutdown, and
        %  other common operative activities? Instinctively I'd say not at
        %  this level, because they are at another level of specificity,
        %  and many have options. Or?
        
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
            termoptions={'xterm','gnome-terminal','desktop','none'};
            q=contains(termoptions,lower(termtype));
            if ~any(q)
                q=numel(termoptions);
            end
            valid = termoptions{q};
        end
    end
end