function Unit=connect(Unit)
    % Connect the unitCS to all its local and remote instruments
    % Purposes:
    % 1) connect all instruments assigned locally to this unit
    % 2) spawn Matlab slaves for all remote instruments, create in them
    %    appropriate unitCS objects, populate them with consistent
    %    property values, and initiate the connections there
    
    for i=1:numel(Unit.PowerSwitch)
        if ~isa(Unit.PowerSwitch{i},'obs.remoteClass')
            Unit.PowerSwitch{i}.classCommand('connect');
        end
    end
    
    pause(2) % a small delay to give timeto the cameras to come up
    
    if isa(Unit.Mount,'obs.mount')
        % real mount
        Unit.Mount.connect(Unit.Mount.PhysicalPort);
    elseif isa(Unit.Mount,'obs.remoteClass')
        % remote mount
        Unit.Mount.connect;
    else
        % no mount at all (usually, mount=obs.LastHandle)
        Unit.report(['no mount defined for unit ',Unit.Id '\n'])
    end
    
    % connect to local focusers and cameras
    for i=1:numel(Unit.LocalTelescopes)
        j=Unit.LocalTelescopes(i);
        Unit.Focuser{j}.connect(Unit.Focuser{j}.PhysicalAddress);
        % connect the camera as last, to add a further small delay
        %  between power on of the first camera and attempt to connect
        Unit.Camera{j}.connect(Unit.Camera{j}.PhysicalId);
    end
    
    % and now remote:
    % - spawn slaves
    for i=1:numel(Unit.Slave)
        % connect the slave
        SlaveUnitName=inputname(1);
        % this is a bit tricky but ensures that the remote unitCS object
        %  gets the right name
        eval([SlaveUnitName '=Unit;']);
        eval(sprintf('%s.connectSlave(%d)',SlaveUnitName,i));
    end

end
