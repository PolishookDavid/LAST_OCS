function Unit=connect(Unit)
    % To be redone completely once the relation between abstraction
    %  connect and driver connect is clarified
    
    Unit.Mount.connect(Unit.Mount.PhysicalPort);

    % connect to local focusers and cameras
    for i=1:numel(Unit.LocalTelescopes)
        j=Unit.LocalTelescopes(i);
        Unit.Camera{j}.connect(Unit.Camera{j}.PhysicalId);
        Unit.Focuser{j}.connect(Unit.Focuser{j}.PhysicalAddress);
    end
    
    % and now remote telescopes need treatment

end
