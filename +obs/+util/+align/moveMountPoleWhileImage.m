function moveMountPoleWhileImage(UnitCS, MountPoleXY, Args)
    % Take images and calc. dist. between mount pole and celestial pole
    % while moving the mount polar alignment.
    % Input  : - A UnitCS object.
    %          - The [X, Y] pixel position of the mount pole as estimated by
    %            obs.util.align.polarAlignPole.
    %          * ...,key,val,...
    %            See code
    % Author : Eran Ofek (Dec 2021)
    
    
    arguments
        UnitCS
        MountPoleXY    % The [X,Y] image position of mount pole
        Args.Camera         = 1;
        Args.TelOffsets     = zeros(4,2); % [2.2 3.3;2.2 -3.3; -2.2 -3.3; -2.2 3.3].*0.5;   % telescope are always numbered: NE, SE, SW, NW 
        Args.PoleCoo        = [0 90];
        Args.Plot logical   = true;
        Args.MarkerNCP      = 'bs';
        Args.MarkerPolaris  = 'ro'; 
        Args.MarkerMount    = 'co';
        Args.MarkerWidth    = 3;
        Args.MarkerSize     = [40 40 0];
        
    end
    
    RAD = 180./pi;
    
    Icam = Args.Camera;
    
    %
    LoopCont = true;
    Ind = 0;
    while LoopCont
        Ind = Ind + 1;
        % take an image
        UnitCS.takeExposure(Args.Cameras, Args.ExpTime, 1);
        UnitCS.readyToExpose(Args.Cameras, true, Args.ExpTime+10);
         
        % solve astrometry
        
        FileName = UnitCS.Camera{Icam}.classCommand('LastImageName');
        [~, Image, S(Ind)] = imProc.astrometry.astrometryCropped(FileName, 'CropSize',[],...
                                                                       'RA',RA+Args.TelOffsets(Icam,1),...
                                                                       'Dec',Dec+Args.TelOffsets(Icam,2));

   
        [MountPoleRA, MountPoleDec] = Image.WCS.xy2sky(MountPoleXY(1), MountPoleXY(2), 'OutUnits','deg');
        [Dist,PA] = celestial.coo.sphere_dist(PoleCoo(1)./RAD, PoleCoo(2)./RAD, MountPoleRA./RAD, MountPoleDec./RAD);
        
        [XCP, YCP] = Image.WCS.sky2xy(Args.PoleCoo(1), Args.PoleCoo(2), 'InUnits','deg');
        
        if Args.Plot
            ds9(Image, 1);
            pause(1);
            ds9.plot(MountPoleXY(1), MountPoleXY(2), Args.MarkerMount,'Size',Args.MarkerSize.*[1 1 0], 'Text','Mount');
            ds9.plot(XCP, YCP,                       Args.MarkerNCP, 'Width',Args.MarkerWidth, 'Size',Args.MarkerSize, 'Text','CP');
        end
        
        fprintf('--- Iteration %d --- \n',Ind);
        fprintf('    MountPole RA: %9.5f, Dec: %9.5f [deg]\n',MountPoleRA,MountPoleDec);
        fprintf('    MountPole distance from celestial pole: %9.2f [arcmin], PA: %5.1f [deg]\n',Dist.*RAD.*60, PA.*RAD);
        
        Ans = input('Click q to quit, any other key to take another image','s');
        switch Ans
            case 'q'
                LoopCont = false;
        end
        
    end
    
    
    
    
end
