function connectSlave(Unit,islaves)
% Create a SpawnedMatlab slave unit, initializing it properly with
%  the required Messenger; create and populate the slave unitCS object,
%  and run the connect methods for the associated hardware.
% This method is called by the main unit upon .connect, but may recalled 
%  later on for a specific slave if that slave needs to be restarted
    
    if ~exist('islaves','var')
        islaves=1:numel(Unit.Slave);
    end
    
    SlaveUnitName=inputname(1);
    
    spawned=false(1,numel(islaves));
    
    for i=1:numel(islaves)
        Unit.report('spawning slave %d\n',islaves(i))
        S=Unit.Slave{islaves(i)};
        S.MessengerLocalPort = []; % arbitrary port numbers, but for definiteness
        S.MessengerRemotePort= 8500+islaves(i);
        S.ResponderLocalPort = [];
        S.ResponderRemotePort= 9500+islaves(i);
        % Spawn a new slave if possible. I doubt that handling the case of 
        %  orphan slaves, and attempting reconnections to existing slaves 
        %  is viable. Slaves should in principle exist only
        %  when the cameras are powered, and we don't want them dangling
        S.spawn
        spawned(i)=isempty(S.LastError);
    end
    
    for i=1:numel(islaves)
        S=Unit.Slave{islaves(i)};
        % create a slave unitCS object and populate it
        if spawned(i) && S.connect
            SlaveUnitId=[Unit.Id '_slave_' num2str(islaves(i))];
            M=S.Messenger;
            M.query(sprintf('%s=obs.unitCS(''%s'');',SlaveUnitName,SlaveUnitId));

            % Pass along Config descriptive (but semi-mandatory,unfortunately)
            %  parameters: .ProjName, .NodeNumber, .TimeZone
            M.query(sprintf('%s.Config.ProjName=''%s'';',SlaveUnitName,...
                            Unit.Config.ProjName));
            M.query(sprintf('%s.Config.NodeNumber=%s;',SlaveUnitName,...
                            num2str(Unit.Config.NodeNumber)));
            M.query(sprintf('%s.Config.TimeZone=%s;',SlaveUnitName,...
                            num2str(Unit.Config.TimeZone)));

            % populate remote power switches
            M.query([SlaveUnitName '.PowerSwitch=cell(1,' ...
                     num2str(numel(Unit.PowerSwitch)) ');']);
            for j=1:numel(Unit.PowerSwitch)
                Sswitch=[SlaveUnitName '.PowerSwitch{' num2str(j) '}'];
                M.query([Sswitch '=obs.remoteClass;']);
                M.query([Sswitch '.RemoteName=''' Sswitch ''';']);
                M.query([Sswitch '.Messenger=MasterResponder;']);
            end
            % copy camera power definitions
            M.query(sprintf('%s.CameraPowerUnit=%s;', ...
                       SlaveUnitName, mat2str(Unit.CameraPowerUnit) ));
            M.query(sprintf('%s.CameraPowerOutput=%s;', ...
                       SlaveUnitName, mat2str(Unit.CameraPowerOutput) ));

            % populate the remote mount
            SMount=[SlaveUnitName '.Mount'];
            M.query([SMount '=obs.remoteClass;']);
            M.query([SMount '.RemoteName=''' SMount ''';']);
            M.query([SMount '.Messenger=MasterResponder;']);

            % populate cameras and focusers
            % Telescopes owned by this slave are configured by its own
            %  configuration file, when created/connected. Of course the
            %  configurations of the master and of its slaves have to be
            %  consistent!
            ownedTelescopes=Unit.RemoteTelescopes{islaves(i)};
            M.query(sprintf('%s.LocalTelescopes=%s;',SlaveUnitName, ...
                             mat2str(ownedTelescopes) ));
            % local cameras and focusers of this unit are remotes of the slave
            for j=Unit.LocalTelescopes
                SCamera=sprintf('%s.Camera{%d}',SlaveUnitName,j);
                M.query([SCamera '=obs.remoteClass;']);
                M.query([SCamera '.RemoteName=''' SCamera ''';']);
                M.query([SCamera '.Messenger=MasterResponder;']);
                SFocuser=sprintf('%s.Focuser{%d}',SlaveUnitName,j);
                M.query([SFocuser '=obs.remoteClass;']);
                M.query([SFocuser '.RemoteName=''' SFocuser ''';']);
                M.query([SFocuser '.Messenger=MasterResponder;']);
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
            M.send([SlaveUnitName '.connect;']);
        end
    end
