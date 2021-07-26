function Unit=connect(Unit)
    % Connect the unitCS to all its local and remote instruments
    % Purposes:
    % 1) connect all instruments assigned locally to this unit
    % 2) spawn Matlab slaves for all remote instruments, create in them
    %    appropriate unitCS objects, populate them with consistent
    %    property values, and initiate the connections there
    
    if isfield(Unit.Mount,'PhysicalPort')
        % real mount
        Unit.Mount.connect(Unit.Mount.PhysicalPort);
    else
        % remote mount
        Unit.Mount.connect;
    end
    
    % connect to local focusers and cameras
    for i=1:numel(Unit.LocalTelescopes)
        j=Unit.LocalTelescopes(i);
        Unit.Camera{j}.connect(Unit.Camera{j}.PhysicalId);
        Unit.Focuser{j}.connect(Unit.Focuser{j}.PhysicalAddress);
    end
    
    % and now remote:
    % - spawn slaves
    for i=1:numel(Unit.Slave)
        % connect the slave
        S=Unit.Slave{i};
        S.LocalPort = 8000+i;
        S.RemotePort= 8000;
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
           M.query([SlaveUnitName '.connect']);
        end
    end

end
