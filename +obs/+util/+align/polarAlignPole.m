function [Result, ResFit] = polarAlignPole(UnitCS, Args)
    % Polar alignment using the circling around pole method
    %   
    % Input  : - A UnitCS object.
    %          * ...,key,val,...
    %            'HA' - Vector of HA [deg] in which to observe.
    %                   One of the values must be zero.
    %                   Default is (-90:45:90).
    %            'Dec' - Pole Declination. Default is 89.99999 [deg].
    %            'Camera' - Camera index. Default is 1.
    % Output : - Astrometric results.
    %          - Fitted results, and deviation from pole.
    % Author : Eran Ofek (Dec 2021)
    
    % need a function that thae images, plot them with circle around coo...
    % align... BestCen, CelPole...
    
    
    
    
    
    arguments
        UnitCS    % UnitCS class
        
        Args.HA      = (-90:45:90);
        Args.Dec     = 89.99999;
        
        Args.PolarisRA  = celestial.coo.convertdms([2 31 49.09],'H','d');      % deg
        Args.PolarisDec = celestial.coo.convertdms([1 89 15 50.8],'D','d');    % deg
        Args.NCP_RA     = 0;
        Args.NCP_Dec    = 90.0;
        Args.PixScale   = 1.25;
        
        Args.Lon        = 34.81694;
        Args.Lat        = 31.91111;
        
        Args.Xalong     = '-ra';
        Args.Yalong     = 'dec';
        
        Args.ExpTime = 3;
        Args.Camera  = 1;  % one camera only
        Args.TelOffsets = zeros(4,2); % [2.2 3.3;2.2 -3.3; -2.2 -3.3; -2.2 3.3].*0.5;   % telescope are always numbered: NE, SE, SW, NW 
        
        
        Args.Plot logical   = true;
        Args.MarkerNCP      = 'bs';
        Args.MarkerPolaris  = 'ro'; 
        Args.MarkerMount    = 'co';
        Args.MarkerWidth    = 3;
        Args.MarkerSize     = [40 40 0];
        
    end
        
    Icam = Args.Camera;
        
    Iha0 = find(abs(Args.HA)<0.1);
    if numel(Iha0)~=1
        error('List of HA must contains a single value with HA=0');
    end
    
    Nha      = numel(Args.HA);
    Args.Dec = Args.Dec(:).*ones(Nha,1);
       
    
    for Iha=1:1:Nha
        
        % set mount coordinates to requested target
        UnitCS.Mount.goTo(Args.HA(Iha), Args.Dec(Iha), 'ha');
        % wait for telescope to arrive to target
        UnitCS.Mount.waitFinish;
        
        % get J2000 RA/Dec from mount (distortion corrected) [deg]
        OutCoo = UnitCS.Mount.j2000;
        RA  = OutCoo(1);
        Dec = OutCoo(2);
        
        Result(Iha).JRA  = RA;
        Result(Iha).JDec = Dec;
        Result(Iha).JHA  = OutCoo(3);
        
        Result(Iha).RA  = UnitCS.Mount.RA;
        Result(Iha).Dec = UnitCS.Mount.Dec;
        Result(Iha).HA  = UnitCS.Mount.HA;
        
        % take exposure and wait till finish
        UnitCS.takeExposure(Args.Cameras, Args.ExpTime, 1);
        UnitCS.readyToExpose(Args.Cameras, true, Args.ExpTime+10);
         
        % get image names
        % Image full names are stored in a cell array FileNames{1..4}
        try
            Result(Iha).FileName = UnitCS.Camera{Icam}.classCommand('LastImageName');
            [~, Result(Iha).Image, Result(Iha).Summary] = imProc.astrometry.astrometryCropped(Result(Iha).FileName,...
                                                                          'CropSize',[],...
                                                                          'RA',RA+Args.TelOffsets(Icam,1),...
                                                                          'Dec',Dec+Args.TelOffsets(Icam,2));
                
            [Result(Iha).PolarisX, Result(Iha).PolarisY] = Result(Iha, Icam).Image.WCS.sky2xy(Args.PolarisRA, Args.PolarisDec, 'InUnits','deg');
            [Result(Iha).NCPX, Result(Iha).NCPY] = Result(Iha, Icam).Image.WCS.sky2xy(Args.NCP_RA, Args.NCP_Dec, 'InUnits','deg');
                
        end
        
        
        
    end

    % fit a circle to the [X,Y] position of polaris in all the images.
    % Find the radius of the circle and its center [X,Y] position.
    X = [Result.PolarisX];
    Y = [Result.PolarisY];
    CircData = [X(:), Y(:)];
    [BestCen,BestRad,BestRMS] = imUtil.util.fit.circ_fit(CircData,'plane');

    ResFit.BestCen = BestCen;
    ResFit.BestRad = BestRad;
    ResFit.BestRMS = BestRMS;

    if Args.Plot
        ds9(Result(Iha0).Image, 1)
        pause(1);

        ds9.plot([Result(Iha).CelPoleX, Result(Iha).CelPoleY], Args.MarkerNCP,     'Width',Args.MarkerWidth, 'Size',Args.MarkerSize, 'Text','CP');
        ds9.plot([[Result.PolarisX].', [Result.PolarisY].'],   Args.MarkerPolaris, 'Width',Args.MarkerWidth, 'Size',Args.MarkerSize, 'Text','Polaris');
        
        ds9.plot(BestCen(1),BestCen(2), InPar.MarkerMount,'Size',Args.MarkerSize.*[1 1 0], 'Text','Mount');
        ds9.plot(BestCen(1),BestCen(2), InPar.MarkerMount,'Size',BestRad);
        
    end
    


    % calc dist between mount pole and celestial pole (calculated -observed)
    % (sign is plus the direction the mount need to move)
    ResFit.DX  = -BestCen(1) + Result(Iha0).CelPoleX;  % pix
    ResFit.DY  = -BestCen(2) + Result(Iha0).CelPoleY;  % pix
    switch lower(Args.Xalong)
        case 'ra'
            ResFit.DAz  = ResFit.DX.*Args.PixScale./60;    % arcmin
        case '-ra'
            ResFit.DAz  = -ResFit.DX.*Args.PixScale./60;    % arcmin
        case 'dec'
            ResFit.DAlt = ResFit.DX.*Args.PixScale./60;    % arcmin
        case '-dec'
            ResFit.DAlt = -ResFit.DX.*Args.PixScale./60;    % arcmin
        otherwise
            error('Unknown RAlong option');
    end
    switch lower(Args.Yalong)
        case 'ra'
            ResFit.DAz = ResFit.DY.*Args.PixScale./60;    % arcmin
        case '-ra'
            ResFit.DAz = -ResFit.DY.*Args.PixScale./60;    % arcmin
        case 'dec'
            ResFit.DAlt = ResFit.DY.*Args.PixScale./60;    % arcmin
        case '-dec'
            ResFit.DAlt = -ResFit.DY.*Args.PixScale./60;    % arcmin
        otherwise
            error('Unknown RAlong option');
    end

    if InPar.Verbose
        fprintf('\n\n');
        fprintf('------------------------\n');
        fprintf('ds9 legend: \n');
        fprintf('    Marker Polaris %s\n',InPar.MarkerPolaris);
        fprintf('    Marker celestial pole %s\n',InPar.MarkerNCP);
        fprintf('    Marker mount pole %s\n',InPar.MarkerMount);    
        fprintf('Shift the mount Az/Alt such that the celestial pole coincides with the mount pole\n');
        fprintf('Required delta X shift [pix]     : %f\n',ResFit.DX);
        fprintf('Required delta Y shift [pix]     : %f\n',ResFit.DY);
        if (ResFit.DAz > 0)
           fprintf('Decrease Az by:  [arcmin] : %f\n',ResFit.DAz);
        else
           fprintf('Increase Az by:  [arcmin] : %f\n',ResFit.DAz);
        end
        if (ResFit.DAlt > 0)
           fprintf('Decrease Alt by [arcmin]: %f\n',ResFit.DAlt);
        else
           fprintf('Increase Alt by [arcmin]: %f\n',ResFit.DAlt);
        end
    end    
    
    
end
    
    
