function Unit=connect(Unit)
    % To be redone completely once the relation between abstraction
    %  connect and driver connect is clarified
    
    Unit.Mount.connect(Unit.Mount.PhysicalPort);

    % connect to focusers and cameras
    for i=1:Unit.NumberLocalTelescopes
        Unit.Camera{i}.connect(Unit.Camera{i}.PhysicalId)
        Unit.Focuser{i}.connect(Unit.Focuser{i}.PhysicalPort)
    end
    

    pause(3);

    for Icam=1:1:Ncam
        F(Icam) = obs.focuser;
        F(Icam).connect([InPar.AddressMount C(Icam).CameraNumber]);
        % assign focuser to camera using CameraNumber
        C(Icam).HandleFocuser = F(Icam);
    end

    if ~isempty(InPar.CameraRemoteName)
        Unit.CameraRemoteName = InPar.CameraRemoteName;
    end

    % connect remote cameras
    if isempty(InPar.CameraRemote)
        RemoteC = [];
    else
        RemoteC      = InPar.CameraRemote; % This should be a connected object
        RemoteC.Name = Unit.CameraRemoteName;

    end

    Unit.HandleMount   = M;
    Unit.HandleCamera  = C;
    Unit.HandleRemoteC = RemoteC;

end
