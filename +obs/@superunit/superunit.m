classdef superunit < obs.LAST_Handle
    % Spawned matlab sessions object, including messengers for dual
    % communication

    properties
        UnitHosts  cell % list of hosts on which to spawn units (cell of char arrays)
        UnitTerminal char ='none';
        SlaveTerminals char ='none';
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
                id=sscanf(S.UnitHosts{i},'last%d');
                S.RemoteUnits(i)=obs.util.SpawnedMatlab(sprintf('master%02d',id));
                % set .RemoteUnit(i).Host. The method .spawn sets it
                %  explicitely, but .connect assumes that is is already set.
                S.RemoteUnits(i).Host=S.UnitHosts{i};
                S.RemoteUnits(i).RemoteTerminal=S.UnitTerminal;
                S.RemoteUnits(i).RemoteMessengerFlavor='listener';
            end
        end
        
        function set.UnitTerminal(S,termtype)
            S.UnitTerminal=termtype;
            for i=1:numel(S.RemoteUnits)
                S.RemoteUnits(i).RemoteTerminal=termtype;
            end
        end
    end
    
    methods
        % connect and disconnect
        function spawn(S,units)
            % spawn includes connect
            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            for i=1:numel(units)
                j=units(i);
                id=sscanf(S.UnitHosts{j},'last%d');
                if isempty(id)
                    id=ceil(sscanf(S.UnitHosts{j},'10.23.1.%d')/2);
                end
                % ok for lastNN machines, would be nice if it worked by IP
                %  as well
                try
                    S.RemoteUnits(j).spawn(S.UnitHosts{j},[],11000,[],13000)
                    S.send(sprintf('Unit=obs.unitCS(''%02d'');',id),j)
                    S.send(sprintf(...
                          'for i=1:numel(Unit.Slave),Unit.Slave{i}.RemoteTerminal=''%s'';end',...
                                                    S.SlaveTerminals),j);
                catch
                    S.reportError('cannot create Unit on host %s',S.UnitHosts{j})
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
                %id=sscanf(S.UnitHosts{units(i)},'last%d');
                S.RemoteUnits(units(i)).MessengerRemotePort=11000;
                S.RemoteUnits(units(i)).ResponderRemotePort=13000;
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
                res{i}=S.RemoteUnits(units(i)).Messenger.query(command);
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
                S.RemoteUnits(units(i)).Messenger.send(command);
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
            %    I.e., a query about Unit.Slave{i}.Status
            %
            % Use case:
            %   S.send('GeneralStatus=''busy'';pause(20);GeneralStatus=''free'';')
            %   S.queryCallback('GeneralStatus')

            if ~exist('units','var') || isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            res=cell(1,numel(units));
            for i=1:numel(units)
                res{i}=S.RemoteUnits(units(i)).Responder.query(command);
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
                S.RemoteUnits(units(i)).Responder.send(command);
            end
        end
        
    end
end