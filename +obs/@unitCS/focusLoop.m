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
%          - Vector of telescope indices. If empty use all. Default is [].
%          * varargin is pairs of ...,key,val,... where the following keys
%            are available:
%            'FocusGuess' - Best focus guess value.
%                   If vector then this is the best focus value for each
%                   camera. Default is the current focuser position.
%            'HalfRange' - Half range of focus loop (i.e., +/- distance of
%                   focus loop from FocusGuess).
%                   If Half range is not consistent with step size, it will
%                   readjusted.
%                   Default is 200.
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
%            'NimExp'   - Number of images per exposure. Default is 1. NOT
%                         USED YET
%            'ImageHalfSize' - Half size of sub image in which to measure
%                   the focus. If empty use full image. Default is 1000.
%            'SeveralPositions' - Nx2 array of positions at which the focus
%                                 is checked, in pixel coordinates. If empty,
%                                 defaults to image center + 6 positions
%                                 on a circle of radius 2000 pixels around
%                                 it. Only for Method='imageFocus'.
%            'SigmaVec' - Vector of gaussian kernel sigma-width (template
%                   bank) with wich to cross-correlate the image.
%                   This will define the range and resolution of the
%                   measured seeing.
%                   Default is [0.1, logspace(0,1,25)].'.
%            'Plot' - Default is true. Will add to existing plot.
%            'Random' - Report random focus values instead of the result
%                       of the focus estimation routine on the image.
%                       Default false. Useful for wet tests when
%                       the cameras cannot see a starry sky image.
%            'Method' - which algorithm to use to evaluate the focus from
%                       the image. Current options are:
%                       'fwhm_fromBank' (new method, default)
%                       'imageFocus' (old method, based on filter2_snBank)
% Output : - A structure with the focus measurments and best value.
%            The following fields are available:
%            .PosVec   - Vector of tested focus positions.
%            .FocVal   - Vector of FWHM [arcsec] at each tested position.
%            .BestFocusFWHM - Best fit FWHM [arcsec]
%            .BestFocusPos  - Best fit focus value.
%            .Az          - Mount Az [deg]
%            .Alt         - Mount Alt [deg]
%            .AM          - Mount airmass []
% By: Eran Ofek          April 2020 ; complete rev. Enrico Segre August 2021
% Example: [FocRes] = Unit.focusLoop(1) 

    UnitObj.GeneralStatus='running focusing loop';

    if nargin<2
        itel=[];
    end
    if isempty(itel)
        itel=1:numel(UnitObj.Camera);
    end

    MountObj=UnitObj.Mount;
    CamObj=UnitObj.Camera(itel);
    FocObj=UnitObj.Focuser(itel);
    SensObj=[]; % to be decided once we include sensors

    PlotMarker    = 'o';
    PlotMinMarker = 'p';

    % this for the first camera, TODO, what if other cameras are different?
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
    addOptional(InPar,'CropSize',[]);
    addOptional(InPar,'ImageHalfSize',1000);  % If [] use full image
    addOptional(InPar,'SeveralPositions',DefSeveralPositions);  % If [] use full image
    addOptional(InPar,'SigmaVec',[0.1, logspace(0,1,25)].');
    addOptional(InPar,'Plot',true);
    addOptional(InPar,'Random',false);
    addOptional(InPar,'Method','fwhm_fromBank',...
                      @(x)any(strcmp(x,{'fwhm_fromBank','imageFocus'})) );
    parse(InPar,varargin{:});
    InPar = InPar.Results;

    if ~isempty(InPar.SeveralPositions) && strcmp(InPar.Method,'imageFocus')
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
        for i=1:Ncam
            InPar.FocusGuess(i)=UnitObj.Focuser{itel(i)}.classCommand('Pos');
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
    for Icam=1:Ncam
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

    % ------------- End argument parsing and preliminaries, operate ----

    Res=struct('PosVec',[],'FocVal',[],'BestFocusFWHM',[],'BestFocusPos',[],...
                'Az',[],'Alt',[],'AM',[]);
    
    % read once for good camera properties which will not change during the
    %  course of this procedure, to avoid multiple reads
    leg=cell(1,Ncam);
    previousImType=cell(1,Ncam);
    PixScale=nan(1,Ncam);
    for Icam=1:Ncam
        leg{Icam}=CamObj{Icam}.classCommand('Id;');
        previousImType{Icam}=CamObj{Icam}.classCommand('ImType;');
        PixScale(Icam)=CamObj{Icam}.classCommand('PixScale;');
    end

    % go to focus start position (which accounts for backlash)
    if ~UnitObj.readyToExpose('Itel',itel, 'Wait',true)
        return
    end
    for Icam=1:Ncam
        FocObj{Icam}.classCommand('Pos=%d;', StartFocus(Icam));
        % set ImType THIS IS USELESS - ImType should be set when calling
        % takeExposure, otherwise it will default to sci
        CamObj{Icam}.classCommand('ImType=''focus'';');
    end
    if ~UnitObj.readyToExpose('Itel',itel,'Wait',true)
        return
    end

    FocVal = nan(Nfocus,Nsp,Ncam);
    for Ifocus=1:Nfocus
        for Icam=1:Ncam
            UnitObj.report('Focuser %d to position: %.0f (#%d out of %d)\n',...
                            itel(Icam), FocusPosCam(Ifocus,Icam), Ifocus, Nfocus)
        end

        % set all focusers
        for Icam=1:Ncam
            FocObj{Icam}.classCommand('Pos=%d;',FocusPosCam(Ifocus,Icam));
        end
        % wait for all focusers
        if ~UnitObj.readyToExpose('Itel',itel,'Wait',true)
            break
        end

        % take one exposure with all cameras
        UnitObj.takeExposure(itel,InPar.ExpTime, varargin{:}, 'ImType','focus');
        % wait for all cameras
        if ~UnitObj.readyToExpose('Itel',itel, 'Wait',true, 'Timeout',InPar.ExpTime+60)  % increased from 20 to 40
            break
        end
        
        %pause(60)

        for Icam=1:Ncam
            % check real focuser position (commanded position might have been
            %  beyond limits)
            actualFocuserPos(Ifocus,Icam)=FocObj{Icam}.classCommand('Pos');
            % measure FWHM for each image taken
            if isa(CamObj{Icam},'obs.camera')
                switch InPar.Method
                    case 'imageFocus'
                        FocVal(Ifocus,:,Icam)=...
                            obs.util.image.imageFocus(CamObj{Icam}.LastImage,...
                                                 InPar.ImageHalfSize,...
                                                 InPar.SigmaVec, PixScale(Icam),...
                                                 InPar.SeveralPositions);
                    otherwise
                        FocVal(Ifocus,:,Icam)=...
                            imUtil.psf.fwhm_fromBank(CamObj{Icam}.LastImage,...
                                            'HalfSize',InPar.ImageHalfSize);
                end
            elseif isa(CamObj{Icam},'obs.remoteClass')
                % do this in slave for remote cameras: construct command...
                switch InPar.Method
                    case 'imageFocus'
                        focuscommand=...
                            sprintf('obs.util.image.imageFocus(%s.LastImage,%g,%s,%g,%s);',...
                            CamObj{Icam}.RemoteName, InPar.ImageHalfSize, ...
                            mat2str(InPar.SigmaVec), PixScale(Icam), ...
                            mat2str(InPar.SeveralPositions) );
                    otherwise
                        focuscommand=...
                            sprintf('imUtil.psf.fwhm_fromBank(%s.LastImage,''HalfSize'',%g);',...
                            CamObj{Icam}.RemoteName, InPar.ImageHalfSize);
                end
                FocVal(Ifocus,:,Icam)=CamObj{Icam}.Messenger.query(focuscommand);
            else
                % do nothing, safeguard
            end
            if InPar.Random
                % to debug, overwrite whichever estimated focus value with
                %  a random number
                FocVal(Ifocus,:,Icam)=5*rand(1,Nsp);
            end
        end
   
        if InPar.Plot
            % clear all matlab plots
            %close all
            nxplot=ceil(sqrt(Ncam));
            nyplot=ceil(Ncam/nxplot);
            clf
            for Icam=1:Ncam
                subplot(nxplot,nyplot,Icam)
                semilogy(actualFocuserPos(:,Icam),FocVal(:,:,Icam),'ko',...
                    'Color',Colors(Icam,:),...
                    'Marker',PlotMarker','MarkerFaceColor',Colors(Icam,:));
                xlim([min(FocusPosCam(:,Icam)),max(FocusPosCam(:,Icam))]);
                hold on
                grid on
                set(gca,'FontSize',10,'XtickLabel',string(get(gca,'Xtick')))
                xlabel('Focus position','FontSize',12);
                ylabel('FWHM [arcsec]','FontSize',12);
                title(leg{Icam},'Interpreter','none')
            end
            drawnow
        end

    end

    Res.PosVec        = actualFocuserPos;
    Res.FocVal        = FocVal;
    Res.BestFocusPos  = nan(Nsp,Ncam);
    Res.BestFocusFWHM = nan(Nsp,Ncam);
    
    for Icam=1:Ncam
        for Isp=1:Nsp
           [Res.BestFocusPos(Isp,Icam),Res.BestFocusFWHM(Isp,Icam)]=...
                obs.util.tools.minimum123(actualFocuserPos(:,Icam),FocVal(:,Isp,Icam));
            if isnan(Res.BestFocusPos(Isp,Icam))
                UnitObj.reportError(['impossible to determine the best focus'...
                    ' position for camera ' leg{Icam}])
            end            
        end
    end
    
    % for many focus points, take as best global focus the mean
    BestFocusPos=mean(Res.BestFocusPos,1);

    if InPar.Plot && ~all(isnan(FocVal(:)))
        for Icam=1:Ncam
            subplot(nxplot,nyplot,Icam)
            semilogy(Res.BestFocusPos(:,Icam),Res.BestFocusFWHM(:,Icam),...
                'Marker',PlotMinMarker,'MarkerSize',10,...
                'MarkerFaceColor',Colors(Icam,:));
        end
        hold off
        grid on
        set(gca,'FontSize',10,'XtickLabel',string(get(gca,'Xtick')))
        title(leg{Icam},'Interpreter','none')
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
            UnitObj.report('Best focus for camera %s @%.0f: FWHM=%f\n',...
                            leg{Icam}, BestFocusPos(Icam),...
                            mean(Res.BestFocusFWHM(:,Icam)))
            FocObj{Icam}.classCommand('Pos = %d;',...
                BestFocusPos(Icam)+InPar.BacklashFocus);
        end
        UnitObj.readyToExpose('Itel',itel, 'Wait',true); % here we could check only focusers
        
        % go to best focus
        for Icam=1:1:Ncam
            FocObj{Icam}.classCommand('Pos = %d;',BestFocusPos(Icam));
        end
    end
    
    % restore whatever was the previous ImType for the cameras
    % This doesn't really do anything, ImType is determined by takeExposure
    for Icam=1:Ncam
        CamObj{Icam}.classCommand('ImType=''%s'';',previousImType{Icam});
    end

    Res.Az  = MountObj.Az;
    Res.Alt = MountObj.Alt;
    Res.AM  = celestial.coo.hardie(pi./2 - Res.Alt.*pi/180);
    
    UnitObj.GeneralStatus='ready'; % well, really "ready" could be checked....
