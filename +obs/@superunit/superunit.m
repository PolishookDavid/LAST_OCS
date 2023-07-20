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
        
        function set.UnitHosts(S,UnitHosts)
            % setter for UnitHosts, constructs all the .RemoteUnits
            S.UnitHosts=UnitHosts;
            Nunits=numel(UnitHosts);
            S.RemoteUnits=repmat(obs.util.SpawnedMatlab,1,Nunits);
            for i=1:Nunits
                id=sscanf(S.UnitHosts{i},'last%d');
                S.RemoteUnits(i)=obs.util.SpawnedMatlab(sprintf('master%02d',id));
                S.RemoteUnits(i).RemoteTerminal=S.UnitTerminal;
                S.RemoteUnits(i).RemoteMessengerFlavor='listener';
            end
        end
        
    end
    
    methods
        % connect and disconnect
        function spawn(S)
            % spawn includes connect
            for i=1:numel(S.RemoteUnits)
                id=sscanf(S.UnitHosts{i},'last%d');
                % of for lastNN machines, would be nice if it worked by IP
                %  as well
                try
                    S.RemoteUnits(i).spawn(S.UnitHosts{i},10000+id,11000+id,12000+id,13000+id)
                    S.send(sprintf('Unit=obs.unitCS(''%02d'');',id),i)
                    S.send(sprintf(...
                          'for i=1:numel(Unit.Slave),Unit.Slave{i}.RemoteTerminal=''%s'';end',...
                                                    S.SlaveTerminals),i);
                catch
                    S.reportError('cannot create Unit on host %s',S.UnitHosts{i})
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