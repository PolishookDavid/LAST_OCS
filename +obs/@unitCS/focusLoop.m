function [Res] = focusLoop(UnitObj,itel,varargin)
% Execute focus loop on LAST telescope
% Package: +obs.util.tools
% Description: Obtain an image with each focus value, and measure the FWHM
%              as a function of focus. Interpolate the best focus value.
%              The focus loop assumes that there is a backlash in the
%              system. In the begining, the focus is set to StartFocus
%              (In LAST StartFocus is higher than the guess focus value).
%              Next the system is going over some user defined focus values
%              and take image with each focus.
%              The program can adapt the focus based on temperature. This
%              is possible if the OCS object is provided with the sensors
%              class.
% Input  : - focusLoop(OCSObject,varargin)
%            Here OCSObject is the single mount OCS object that contains
%            the mount, camera, and focuser objects.
%            [If sensor object is empty then do not use temperature.
%             Omit SensorObj if absent] TODO
%          * varargin is pairs of ...,key,val,... where the following keys
%            are availble:
%            'FocusGuess' - Best focus guess value.
%                   If vector then this is the best focus value for each
%                   camera. Default is the current focuser position.
%            'HalfRange' - Half range of focus loop (i.e., +/- distance of
%                   focus loop from FocusGuess).
%                   If Half range is not consistent with step size, it will
%                   readjusted.
%                   Default is 120.
%            'Step' - Focus loops steps. Default is 40.
%            'FocusGuessTemp' - If the focus guess parameter is temperature
%                   dependent. This is the nominal temperature of the
%                   FocusGuess value. If NaN ignore temperature.
%                   Default is 25.
%            'FocusTempGrad' - The gradient of the focus with
%                   temperature [focus value/1°C].
%                   Default is 0.
%            'BacklashFocus' - A focus value relative to the estimated best
%                   focus value (- below / + above)
%                   from which to start moving, in order to deal with
%                   backlash. 
%                   The sign of this argument defines the direction of the
%                   backlash. Default is 150.
%            'ExpTime'  - Exposure time. Default is 5 sec.
%            'NimExp'   - Number of images per exposure. Default is 1.
%            'ImageHalfSize' - Half size of sub image in which to measure
%                   the focus. If empty use full image. Default is 1000.
%            'SeveralPositions' - Nx2 array of positions at which the focus
%                                 is checked, in pixel coordinates. If empty,
%                                 defaults to image center + 6 positions
%                                 on a circle of radius 2000 pixels around
%                                 it.
%            'SigmaVec' - Vector of gaussian kernel sigma-width (template
%                   bank) with wich to cross-correlate the image.
%                   This will define the range and resolution of the
%                   measured seeing.
%                   Default is [0.1, logspace(0,1,25)].'.
%            'PixScale' - ["/pix]. Default is 1.25"/pix.
%            'Plot' - Default is true. Will add to existing plot.
% Output : - A structure with the focus measurments and best value.
%            The following fields are available:
%            .PosVec   - Vector of tested focus positions.
%            .FocVal   - Vector of FWHM [arcsec] at each tested position.
%            .BestFocFWHM - Best fit FWHM [arcsec]
%            .BestFocusPos  - Best fit focus value.
%            .Az          - Mount Az [deg]
%            .Alt         - Mount Alt [deg]
%            .AM          - Mount airmass []
% By: Eran Ofek          April 2020 ; complete rev. Enrico Segre August 2021
% Example: [FocRes] = Unit.focusLoop(1) 

    MountObj=UnitObj.Mount;
    CamObj=UnitObj.Camera(itel);
    FocObj=UnitObj.Focuser(itel);
    SensObj=[]; % to be decided once we include sensors

    PlotMarker    = 'o';
    PlotMinMarker = 'p';

    effA=CamObj{1}.classCommand('effective_area'); % this is maybe only for QHYccd?
    CenterPos=double([effA.syEff,effA.sxEff]/2);
    Theta     = (0:60:300).';
    DefSeveralPositions = [CenterPos; CenterPos + 2000.*[cosd(Theta), sind(Theta)]];

    InPar = inputParser;
    addOptional(InPar,'FocusGuess',[]);  
    addOptional(InPar,'HalfRange',200);  
    addOptional(InPar,'Step',40);  
    addOptional(InPar,'FocusGuessTemp',25);  
    addOptional(InPar,'FocusTempGrad',0);  
    addOptional(InPar,'BacklashFocus',200);  
    addOptional(InPar,'ExpTime',5);  
    addOptional(InPar,'NimExp',1);  
    addOptional(InPar,'ImageHalfSize',1000);  % If [] use full image
    addOptional(InPar,'SeveralPositions',DefSeveralPositions);  % If [] use full image
    addOptional(InPar,'SigmaVec',[0.1, logspace(0,1,25)].');
    addOptional(InPar,'PixScale',1.25);  % "1/pix
    addOptional(InPar,'Plot',true);
    parse(InPar,varargin{:});
    InPar = InPar.Results;

    if ~isempty(InPar.SeveralPositions)
        InPar.ImageHalfSize = [];
        Nsp=size(InPar.SeveralPositions,1);
    else
        Nsp=1;
    end

    % number of cameras and focusers
    Ncam = numel(itel);

    if InPar.Plot
        Colors = plot.generate_colors(Ncam);
    end

    % number of focus steps
    Nfocus = floor(InPar.HalfRange./InPar.Step).*2 + 1;
    % adapt HalfRange accoring to number of steps
    InPar.HalfRange = InPar.Step.*(Nfocus-1).*0.5;

    if isempty(InPar.FocusGuess)
        % take the current focus as best guess, if not otherwise provided
        InPar.FocusGuess=NaN(Ncam,1);
        for i=itel
            InPar.FocusGuess(i)=UnitObj.Focuser{i}.classCommand(sprintf('Pos'));
        end
    end
    
    % make sure FocusGuess is a column vector of length Ncam
    InPar.FocusGuess = InPar.FocusGuess(:).*ones(Ncam,1);

    % Estimate focus based on temperature
    if InPar.FocusTempGrad==0 || isempty(SensObj)
        AmbTemp = InPar.FocusGuessTemp;
    else
        % read ambient temperature
        AmbTemp = mean(SensObj.Temp(1:2));
    end

    % Estimate best focus based on temperature
    FocusGuess  = InPar.FocusGuess + ...
                  (AmbTemp - InPar.FocusGuessTemp).*InPar.FocusTempGrad;

    % backlash direction: + means the start value is above the best guess value
    BacklashDir = sign(InPar.BacklashFocus);
    % Start pos is a vector of length Ncam % TODO: now it is a scalar...
    StartFocus    = InPar.FocusGuess + InPar.BacklashFocus;

    % prepare a table of focus values to test for each camera
    % Each column is the focus values for each camera.
    FocusPosCam = nan(Nfocus,Ncam);
    for Icam=1:1:Ncam
        FocusPosCam(:,Icam) = ((FocusGuess(Icam)-InPar.HalfRange): InPar.Step :...
                               (FocusGuess(Icam)+InPar.HalfRange)).';
    end

    %Limits = [FocusGuess - InPar.HalfRange, FocusGuess + InPar.HalfRange];

    %PosVec = (Limits(1):InPar.Step:Limits(2)).';
    if BacklashDir>0
        FocusPosCam = flipud(FocusPosCam);
    else
        % no need to reverse PosVec
    end

    actualFocuserPos = FocusPosCam; %will be corrected later by actual reading

    % End argument parsing and preliminaries, operate

    Res=struct('PosVec',[],'FocVal',[],'BestFocFWHM',[],'BestFocusPos',[],...
                'Az',[],'Alt',[],'AM',[]);

    % go to focus start position (but why? not to FocusValCam(1)?)
    if ~UnitObj.readyToExpose(itel,true)
        return
    end
    for Icam=1:Ncam
        FocObj{Icam}.classCommand(sprintf('Pos=%d;', StartFocus)); % TODO vector StartFocus
    end
    if ~UnitObj.readyToExpose(itel,true)
        return
    end

    FocVal = nan(Nfocus,Nsp,Ncam);
    for Ifocus=1:Nfocus
        for Icam=1:Ncam
            UnitObj.report(sprintf('Focuser %d at position: %f (#%d out of %d)\n',...
                                   Icam, FocusPosCam(Ifocus,Icam), Ifocus, Nfocus));
        end

        % set all focusers
        for Icam=1:1:Ncam
            FocObj{Icam}.classCommand(sprintf('Pos=%d;',FocusPosCam(Ifocus,Icam)));
        end
        % wait for all focusers
        if ~UnitObj.readyToExpose(itel,true)
            break
        end

        % take one exposure with all cameras
        UnitObj.takeExposure(itel,InPar.ExpTime);
        % wait for all cameras
        if ~UnitObj.readyToExpose(itel,true,InPar.ExpTime+10)
            break
        end

        for Icam=1:1:Ncam
            % check real focuser position (commanded position might have been
            %  beyond limits)
            actualFocuserPos(Ifocus,Icam)=FocObj{Icam}.classCommand(sprintf('Pos'));
            % measure FWHM for each image taken
            if isa(CamObj(Icam),'obs.camera')
                FocVal(Ifocus,:,Icam)=imageFocus(CamObj(Icam).LastImage,...
                                                 InPar.ImageHalfSize,...
                                                 InPar.SigmaVec, InPar.PixScale,...
                                                 InPar.SeveralPositions);
            elseif isa(CamObj(Icam),'obs.remoteClass')
                % do this in slave for remote cameras: construct command...
                focuscommand= sprintf('imageFocus(%s.LastImage,%g,%s,%g,%s);',...
                              CamObj(Icam).RemoteName, InPar.ImageHalfSize, ...
                              mat2str(InPar.SigmaVec), InPar.PixScale, ...
                              mat2str(InPar.SeveralPositions) );
                FocVal(Ifocus,:,Icam)=CamObj(Icam).Messenger.query(focuscommand);
            else
                % do nothing, safeguard
            end
            % FIXME temporary, to debug
            FocVal(Ifocus,:,Icam)=5*rand(1,Nsp);
        end

        
        if InPar.Plot
            % clear all matlab plots
            %close all
            clf
            for Icam=1:1:Ncam           
                plot(actualFocuserPos(:,Icam),FocVal(:,:,Icam),'ko',...
                     'Color',Colors(Icam,:),...
                     'Marker',PlotMarker','MarkerFaceColor',Colors(Icam,:));
                xlim([min(FocusPosCam,[],'all'),max(FocusPosCam,[],'all')]);
                hold on
            end
            xlabel('Focus position','FontSize',18);
            ylabel('FWHM [arcsec]','FontSize',18);
            drawnow
        end

    end

    Res.PosVec      = actualFocuserPos;
    Res.FocVal      = FocVal;
    Res.BestFocusPos=nan(Nsp,Ncam);
    Res.BestFocusFWHM=nan(Nsp,Ncam);
    
    for Isp=1:Nsp
        for Icam=1:Ncam
            usableFocusImages=find(~isnan(FocVal(:,Isp,Icam)));
            switch numel(usableFocusImages)
                case 0
                    UnitObj.reportError(['impossible to determine the best focus'...
                        ' position for camera ' CamObj{Icam}.Id])
                case 1
                    % only one position with non NaN focus, use it
                    Res.BestFocusPos(Isp,Icam)=actualFocuserPos(usableFocusImages,Icam);
                    Res.BestFocFWHM(Isp,Icam)=FocVal(usableFocusImages,Isp,Icam);
                case 2
                    % two positions with non NaN focus, use the best
                    [Res.BestFocFWHM(Isp,Icam),imin]=...
                        min(FocVal(usableFocusImages,Isp,Icam));
                    Res.BestFocusPos(Isp,Icam)=actualFocuserPos(imin,Icam);
                otherwise
                    [~,imin] = min(FocVal(usableFocusImages,Isp,Icam));
                    % minimum if the minimum is at the extremum
                    if usableFocusImages(1)==imin || usableFocusImages(end)==imin
                        Res.BestFocusPos(Isp,Icam)=actualFocuserPos(imin,Icam);
                        Res.BestFocFWHM(Isp,Icam)=FocVal(imin,Isp,Icam);
                    else
                        % otherwise, three point parabolic interpolation
                        q=find(usableFocusImages==imin);
                        p=usableFocusImages(q-1:q+1);
                        f=actualFocuserPos(p,Icam);
                        v=FocVal(p,Isp,Icam);
                        [Res.BestFocusPos(Isp,Icam),Res.BestFocFWHM(Isp,Icam)]=...
                            obs.util.tools.parabolicInterpolation(f,v);
                    end
            end
            
        end
    end
    
    % for many focus point, take as best global focus the mean
    BestFocusPos=mean(Res.BestFocusPos,1);

    % no sense all this report for many cameras and many focus points
    % UnitObj.report(sprintf('Best focus value  : %f\n',BestFocusPos));
    % UnitObj.report(sprintf('FWHM at best focus: %f\n',Res.BestFocFWHM));

    if InPar.Plot
        for Icam=1:1:Ncam
            plot(Res.BestFocusPos(:,Icam),Res.BestFocFWHM(:,Icam),...
                 'Marker',PlotMinMarker,'MarkerFaceColor',Colors(Icam,:));
        end
        hold off
        drawnow
    end

    % we should move to the best focus only if there was no unit fault
    %  throughout the loop, and if it was really possible to find the
    %  optimum
    if all(~isnan(BestFocusPos)) % FIXME, the ok condition
        if Ncam==1
            UnitObj.report('Moving the focuser at its best position\n');
        else
            UnitObj.report('Moving the focusers at their best positions\n');
        end
        
        % move up (best+backlash, was - start position to avoid backlash)
        for Icam=1:1:Ncam
            FocObj{Icam}.classCommand(sprintf('Pos = %d;',...
                BestFocusPos(Icam)+InPar.BacklashFocus));
        end
        UnitObj.readyToExpose(itel,true); % here we could check only focusers
        
        % go to best focus
        for Icam=1:1:Ncam
            FocObj{Icam}.classCommand(sprintf('Pos = %d;',BestFocusPos(Icam)));
        end
    end
    
    Res.Az  = MountObj.Az;
    Res.Alt = MountObj.Alt;
    Res.AM  = celestial.coo.hardie(pi./2 - Res.Alt.*pi/180);
