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
    elseif isa(Unit.Mount,'obs.remoteClass')
        % remote mount
        Unit.Mount.connect;
    else
        % no mount at all (usually, mount=LastHandle)
        Unit.report(['no mount defined for unit ',Unit.Id '\n'])
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
        SlaveUnitName=inputname(1);
        % this is a bit tricky but ensures that the remote unitCS object
        %  gets the right name
        eval([SlaveUnitName '=Unit;']);
        eval(sprintf('%s.connectSlave(%d)',SlaveUnitName,i));
    end

end
