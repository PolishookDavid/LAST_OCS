classdef superunit < obs.LAST_Handle
    % Spawned matlab sessions object, including messengers for dual
    % communication

    properties
        UnitHosts  cell % list of hosts on which to spawn units (cell of char arrays)
        RemoteTerminal char ='none';
        RemoteUnits obs.util.SpawnedMatlab; % array of SpawnedMatlabs;
        Logging logical =false; % create stdout and stderr log files. Must be set BEFORE connect
        LoggingDir char ; % directory where to log. Must be set BEFORE connect
    end

    methods
        % constructor and destructor
        function S=superunit()
            Nunits=numel(S.UnitHosts);
            S.RemoteUnits=repmat(obs.util.SpawnedMatlab,1,Nunits);
            for i=1:Nunits
                id=sscanf(S.UnitHosts{i},'last%d');
                S.RemoteUnits(i)=obs.util.SpawnedMatlab(sprintf('super%02d',id));
                S.RemoteUnits(i).RemoteTerminal='none';
            end
        end
        
        function delete(S)
            % maybe not needed, the destructor od SpawnedMatlab should do
            for i=1:Nunits
                % S.RemoteUnits(i).disconnect;
            end
        end
    end
    
    methods
        % connect and disconnect
        function connect(S)
            for i=1:numel(S.RemoteUnits)
                id=sscanf(S.UnitHosts{i},'last%d');
                S.RemoteUnits(i).connect(S.UnitHosts{i},1000+id,1100+id,1200+id,1300+id)
                S.RemoteUnits(i).Messenger.send(sprintf('Unit=obs.unitCS(''%02d'');',id))
                S.RemoteUnits(i).Messenger.send('for i=1:4,Unit.Slave{i}.RemoteTerminal=''none'';end')
            end
        end
        
        function disconnect(S)
             for i=1:numel(S.RemoteUnits)
                 S.RemoteUnits(i).disconnect;
             end
        end
        
        % shortcuts for sending multiple commands
        function res=query(S,units,command)
            % query the same command to one or more units
            %  note: this is serial, the next command is sent only after
            %  the previous reply has arrived
            if isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            res=cell(1,numel(units));
            for i=numel(units)
                res{i}=S.RemoteUnits(units(i)).Messenger.query(command);
            end
        end
        
        function send(S,units,command)
            % send the same command to one or more units, without waiting
            %  for replies
            if isempty(units)
                units=1:numel(S.RemoteUnits);
            end
            for i=numel(units)
                S.RemoteUnits(units(i)).Messenger.send(command);
            end
        end
        
    end
end