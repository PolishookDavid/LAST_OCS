function Summary = alignCameraRotation(UnitCS, Args)
    % An aux function for camera rotation alignment and telescope alignment
    %       Take images along several HA on the Equator. For each image,
    %       solve astrometry and calculate field rotation.
    %       Return the median rotation for each camera.
    % Input  : - A unitCS object.
    %          * ...,key,val,...
    %            'HA' - Vector of H.A. in which to take images [deg].
    %                   Default is [-60, -30, 0, 30, 60].
    %            'Dec' - Vector of Dec [deg]. Default is 0.
    %            'ExpTime' - Default is 3 s.
    %            'Cameras' - List of cameras. Default is [1 2 3 4].
    %            'TelOffsets' - A two column matrix of telescope offsets
    %                   [deg] relative to mount pointiong [DeltaRA, DeltaDec]
    %                   Default is [2.2 3.3;2.2 -3.3; -2.2 -3.3; -2.2 3.3].*0.5
    %            ** NOTE: if not given, instead of a default, should be
    %                     taken from
    %                     UnitCS.Camera{Cameras}.lassCommand('TelescopeOffset')
    % Outout : - A summary structure
    %            .S - Structure array of [HA, Cam] for astrometric summary
    %                   for each HA/camera.
    %            .MountJ - J2000.0 RA/Dec/HA for each mount pointing.
    %            .MountD - Equinox of date mount (no distortion) coo for
    %                   each mount pointing.
    %            .MedRot - A vector of median rotation, for each camera
    %                   [deg].
    %            .StdRot - A vector of std rotation, for each camera
    %                   [deg].
    %            .OffsetLong - Matrix of offset between mount J2000 RA position
    %                   and camera position for each [Ha, Cam]. [deg]
    %            .OffsetLat - Matrix of offset between mount J2000 Dec position
    %                   and camera position for each [Ha, Cam]. [deg]
    %            .OffsetDist - Matrix of dist between mount J2000 position
    %                   and camera position for each [Ha, Cam]. [deg]
    %            .OffsetPA - Matrix of PA between mount J2000 position
    %                   and camera position for each [Ha, Cam]. [deg]
    % Author : Eran Ofek (Dec 2021)
    % Example: Summary = obs.util.align.alignCameraRotation(UnitCS);
    
    arguments
        UnitCS    % UnitCS class
        Args.HA      = [-60, -30, 0, 30, 60];
        Args.Dec     = 0;
        
        Args.ExpTime = 3;
        Args.Cameras = [1 2 3 4];
        Args.TelOffsets = [2.2 3.3;2.2 -3.3; -2.2 -3.3; -2.2 3.3].*0.5;   % telescope are always numbered: NE, SE, SW, NW 
        
    end
   
    RAD = 180./pi;
    
    if isempty(Args.TelOffsets)
        %% read telescope offset relative to mount from properties
    end
    
    Nha      = numel(Args.HA);
    Args.Dec = Args.Dec(:).*ones(Nha,1);
    Ncam     = numel(Args.Cameras);
    
    for Iha=1:1:Nha
        
        % set mount coordinates to requested target
        UnitCS.Mount.goTo(Args.HA(Iha), Args.Dec(Iha), 'ha');
        % wait for telescope to arrive to target
        UnitCS.Mount.waitFinish;
        
        % get J2000 RA/Dec from mount (distortion corrected) [deg]
        OutCoo = UnitCS.Mount.j2000;
        RA  = OutCoo(1);
        Dec = OutCoo(2);
        
        MountJ(Iha).RA  = RA;
        MountJ(Iha).Dec = Dec;
        MountJ(Iha).HA  = OutCoo(3);
        
        MountD(Iha).RA  = UnitCS.Mount.RA;
        MountD(Iha).Dec = UnitCS.Mount.Dec;
        MountD(Iha).HA  = UnitCS.Mount.HA;
        
        
        % take exposure and wait till finish
        UnitCS.takeExposure(Args.Cameras, Args.ExpTime, 1);
        UnitCS.readyToExpose(Args.Cameras, true, Args.ExpTime+10);
         
        % get image names
        % Image full names are stored in a cell array FileNames{1..4}
        for Icam=1:1:Ncam
            IndCam = Args.Cameras(Icam);
            try
                FileNames{Icam} = UnitCS.Camera{IndCam}.classCommand('LastImageName');
                [~, ~, S(Iha,Icam)] = imProc.astrometry.astrometryCropped(FileNames{IndCam}, 'RA',RA+Args.TelOffsets(IndCam,1),...
                                                                                       'Dec',Dec+Args.TelOffsets(IndCam,2));
            end
        end
    end
        
    Summary.S = S;
    Summary.MountJ = MountJ;
    Summary.MountD = MountD;
    
    for Icam=1:1:Ncam
        Summary.MedRot(Icam)  = median([S(:,Icam).Rotation]);
        Summary.StdRot(Icam)  = std([S(:,Icam).Rotation]);
    end
    
    Summary.OffsetLong = nan(Nha, Ncam);
    Summary.OffsetLat  = nan(Nha, Ncam);
    Summary.OffsetDist = nan(Nha, Ncam);
    Summary.OffsetPA   = nan(Nha, Ncam);
    for Iha=1:1:Nha
        for Icam=1:1:Ncam
            IndCam = Args.Cameras(Icam);  
            [Summary.OffsetLong(Iha,Icam), Summary.OffsetLat(Iha,Icam), Summary.OffsetDist(Iha,Icam), Summary.OffsetPA(Iha,Icam)] = celestial.coo.sphere_offset(Summary.MountJ(Iha).RA./RAD, Summary.S(Iha,Icam)./RAD);
        end
    end
    Summary.OffsetLong = Summary.OffsetLong.*RAD;
    Summary.OffsetLat  = Summary.OffsetLat .*RAD;
    Summary.OffsetDist = Summary.OffsetDist.*RAD;
    Summary.OffsetPA   = Summary.OffsetPA  .*RAD;
    
end
