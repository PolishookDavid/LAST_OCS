function Unit=connect(Unit)
    % Connect the unitCS to all its local and remote instruments
    % Purposes:
    % 1) turn on on power of mount and cameras
    % 2) connect all instruments assigned locally to this unit
    % 3) spawn Matlab slaves for all remote instruments, create in them
    %    appropriate unitCS objects, populate them with consistent
    %    property values, and initiate the connections there
    % This method is designed to be called both for the master Unit and for
    %  its copies in eventual slaves.
    
    % for powering on, we could rely only on the right states being written
    %  in the power switches configuration files. Let's assume that the
    %  power switches are always controlled by the Master
    for i=1:numel(Unit.PowerSwitch)
        if ~isa(Unit.PowerSwitch{i},'obs.remoteClass')
            Unit.PowerSwitch{i}.classCommand('connect');
        end
    end
    
    % however, turning explicitely on the powers would be perhaps safer 
    %  and clearer - but would need more gymnastics in slaves, also
    %  the switches configurationswould need to be copied there
    % Unit.CameraPower(:)=true;
    % Unit.MountPower=true;

    pause(2) % a small delay to give time to the cameras to come up
    
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
