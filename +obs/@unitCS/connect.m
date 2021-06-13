function Obj=connect(Obj,varargin)
    % description to be written yet....

    InPar = inputParser;
    addOptional(InPar,'MountType','XerxesMount');
    addOptional(InPar,'AddressMount',[1 1]);
    addOptional(InPar,'Ncam',2);
    %addOptional(InPar,'CameraNumber',[1 3]); %[1 3]);
    addOptional(InPar,'CameraRemote',[]); %[1 3]);
    addOptional(InPar,'CameraType','QHY');
    addOptional(InPar,'CameraRemoteName','C');  % if empty then do not populate
    parse(InPar,varargin{:});
    InPar = InPar.Results;

    if Obj.Verbose
        fprintf('Connect to mount Node=%d, Mount=%d\n',InPar.AddressMount);
    end

    M = obs.mount(InPar.MountType);
    M.connect(InPar.AddressMount);

    % connect to fcusers and cameras
    C = obs.camera(InPar.CameraType,InPar.Ncam);
    C.connect('all');
    Ncam = numel(C);

    pause(3);

    for Icam=1:1:Ncam
        F(Icam) = obs.focuser;
        F(Icam).connect([InPar.AddressMount C(Icam).CameraNumber]);
        % assign focuser to camera using CameraNumber
        C(Icam).HandleFocuser = F(Icam);
    end

    if ~isempty(InPar.CameraRemoteName)
        Obj.CameraRemoteName = InPar.CameraRemoteName;
    end

    % connect remote cameras
    if isempty(InPar.CameraRemote)
        RemoteC = [];
    else
        RemoteC      = InPar.CameraRemote; % This should be a connected object
        RemoteC.Name = Obj.CameraRemoteName;

    end

    Obj.HandleMount   = M;
    Obj.HandleCamera  = C;
    Obj.HandleRemoteC = RemoteC;

end
