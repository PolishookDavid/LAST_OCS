function connectSlave(Unit,islaves)
% Create a SpawnedMatlab slave unit, initializing it properly with
%  the required Messenger; create and populate the slave unitCS object,
%  and run the connect methods for the associated hardware.
% This method is called by the main unit upon .connect, but may recalled 
%  later on for a specific slave if that slave needs to be restarted
    
    if ~exist('islaves','var')
        islaves=1:numel(Unit.Slaves);
    end
    
    for i=islaves
        S=Unit.Slave{i};
        S.LocalPort = 8000+i;
        S.RemotePort= 9000+i;
        S.connect
        % create a slave unitCS object and populate it
        if isempty(S.LastError)
            SlaveUnitName=inputname(1);
            SlaveUnitId=[Unit.Id '_slave_' num2str(i)];
            SMount=[SlaveUnitName '.Mount'];
            M=S.Messenger;
            M.query(sprintf('%s=obs.unitCS(''%s'');',SlaveUnitName,SlaveUnitId));
            % populate the remote mount
            M.query([SMount '=obs.remoteClass;']);
            M.query([SMount '.RemoteName=''' SMount ''';']);
            M.query([SMount '.Messenger=MasterMessenger;']);
            % populate cameras and focusers
            % Telescopes owned by this slave are configured by its own
            %  configuration file, when created/connected. Of course the
            %  configurations of the master and of its slaves have to be
            %  consistent!
            ownedTelescopes=Unit.RemoteTelescopes{i};
            M.query([sprintf('%s.LocalTelescopes=[',SlaveUnitName), ...
                sprintf('%d ',ownedTelescopes) '];' ] );
            % local cameras and focusers of this unit are remotes of the slave
            for j=Unit.LocalTelescopes
                SCamera=sprintf('%s.Camera{%d}',SlaveUnitName,j);
                M.query([SCamera '=obs.remoteClass;']);
                M.query([SCamera '.RemoteName=''' SCamera ''';']);
                M.query([SCamera '.Messenger=MasterMessenger;']);
                SFocuser=sprintf('%s.Focuser{%d}',SlaveUnitName,j);
                M.query([SFocuser '=obs.remoteClass;']);
                M.query([SFocuser '.RemoteName=''' SFocuser ''';']);
                M.query([SFocuser '.Messenger=MasterMessenger;']);
            end
            % set in the local unit the messenger and remote name of remote telescopes
            %  handled by this slave
            for j=ownedTelescopes
                SCamera=sprintf('%s.Camera{%d}',SlaveUnitName,j);
                SFocuser=sprintf('%s.Focuser{%d}',SlaveUnitName,j);
                Unit.Camera{j}.RemoteName = SCamera;
                Unit.Camera{j}.Messenger = M;
                Unit.Focuser{j}.RemoteName = SFocuser;
                Unit.Focuser{j}.Messenger = M;
            end
            % send the connect command to the slave unit object, to connect
            %  with its own hardware
            M.query([SlaveUnitName '.connect;']);
        end
    end
