function Summary = alignCameraRotation(UnitCS, Args)
    % An aux function for camera rotation alignment
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
    % Outout : - A summary structure
    %            .S - Structure array of [HA, Cam] for astrometric summary
    %                   for each HA/camera.
    %            .MedRot - A vector of median rotation, for each camera
    %                   [deg].
    %            .StdRot - A vector of std rotation, for each camera
    %                   [deg].
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
        
        % take exposure and wait till finish
        UnitCS.takeExposure(Args.Cameras, Args.ExpTime, 1);
        UnitCS.readyToExpose(Args.Cameras, true, Args.ExpTime+10);
         
        % get image names
        % Image full names are stored in a cell array FileNames{1..4}
        for Icam=1:1:Ncam
            try
                FileNames{Icam} = UnitCS.Camera{Icam}.classCommand('LastImageName');
                [~, ~, S(Iha,Icam)] = imProc.astrometry.astrometryCropped(FileNames{Icam}, 'RA',RA+Args.TelOffsets(Icam,1),...
                                                                                       'Dec',Dec+Args.TelOffsets(Icam,2));
            end
        end
    end
        
    Summary.S = S;
    for Icam=1:1:Ncam
        Summary.MedRot(Icam)  = median([S(:,Icam).Rotation]);
        Summary.StdRot(Icam)  = std([S(:,Icam).Rotation]);
    end
    
end
