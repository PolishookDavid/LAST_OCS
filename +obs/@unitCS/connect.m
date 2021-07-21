function Unit=connect(Unit)
    % To be redone completely once the relation between abstraction
    %  connect and driver connect is clarified
    
    if isfield(Unit.Mount,'PhysicalPort')
        % real mount
        Unit.Mount.connect(Unit.Mount.PhysicalPort);
    else
        % remote mount
        Unit.Mount.connect
    end
    
    % connect to local focusers and cameras
    for i=1:numel(Unit.LocalTelescopes)
        j=Unit.LocalTelescopes(i);
        Unit.Camera{j}.connect(Unit.Camera{j}.PhysicalId);
        Unit.Focuser{j}.connect(Unit.Focuser{j}.PhysicalAddress);
    end
    
    % and now remote:
    % - spawn slaves
    Nlocal=numel(Unit.LocalTelescopes);
    Nremote=numel(horzcat(Unit.RemoteTelescopes{:}));
    for i=1:numel(Unit.Slave)
        Unit.Slave{i}.LocalPort= 8000+i;
        Unit.Slave{i}.RemotePort= 8000;
        Unit.Slave{i}.connect
        % create a slave unitCS object in each slave and populate it
        if isempty(Unit.Slave{i}.LastError)
           SlaveUnitName=inputname(1);
           SlaveUnitId=[Unit.Id '_slave_' num2str(i)];
           M=Unit.Slave{i}.Messenger;
           M.query(sprintf('%s=obs.unitCS(''%s'')',SlaveUnitName,SlaveUnitId));
           % populate remote mount
           M.query(sprintf('%s.Mount=obs.remoteClass;',SlaveUnitName));
           M.query(sprintf('%s.Mount.RemoteName=''%s.Mount'';',SlaveUnitName,inputname(1)));
           M.query(sprintf('%s.Mount.Messenger=MasterMessenger;',SlaveUnitName));
           % populate cameras and focusers
           % Telescopes owned by this slave are configured by its own
           %  configuration file, when created/connected. Of course the
           %  configurations of master and its slaves have to be
           %  consistent!
           ownedTelescopes=Unit.RemoteTelescopes{i};
           % local cameras and focusers of this unit as remotes of the slave
           for j=Unit.LocalTelescopes
               M.query(sprintf('%s.Camera{%d}=obs.remoteClass;',SlaveUnitName,j));
               M.query(sprintf('%s.Camera{%d}.RemoteName=''%s.Camera{%d}'';'...
                                        ,SlaveUnitName,j,SlaveUnitName,j));
               M.query(sprintf('%s.Camera{%d}.Messenger=MasterMessenger;',SlaveUnitName,j));
               M.query(sprintf('%s.Focuser{%d}=obs.remoteClass;',SlaveUnitName,j));
               M.query(sprintf('%s.Focuser{%d}.RemoteName=''%s.Focuser{%d}'';'...
                                        ,SlaveUnitName,j,SlaveUnitName,j));
               M.query(sprintf('%s.Focuser{%d}.Messenger=MasterMessenger;',SlaveUnitName,j));
           end
           % set the messenger of remote telescopes of this unit handled by
           %  this slave
           for j=ownedTelescopes
               Unit.Camera{j}.Messenger=M;
               Unit.Focuser{j}.Messenger=M;
           end
           % send the connect command to the slave unit object, to connect
           %  with slave hardware
           % RECEIVED AS ILLEGAL, CHECK
           M.query(sprintf('%s.connect',SlaveUnitName));
        end
    end

end
