function Unit=connect(Unit)
    % To be redone completely once the relation between abstraction
    %  connect and driver connect is clarified
    
    Unit.Mount.connect(Unit.Mount.PhysicalPort);

    % connect to local focusers and cameras
    for i=1:Unit.NumberLocalTelescopes
        Unit.Camera{i}.connect(Unit.Camera{i}.PhysicalId);
        Unit.Focuser{i}.connect(Unit.Focuser{i}.PhysicalAddress);
    end
    
    % and now remote telescopes need treatment

end
