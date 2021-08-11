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
% Input  : - obs.util.tools.focus_loop(CameraObject,MountObject,FocusObject,SensorObj,varargin)
%            or obs.util.tools.focus_loop(OCSObject,varargin)
%            Here OCSObject is the single mount OCS object that contains
%            the mount, camera, and focus objects.
%            If sensor object is empty then do not use temperature.
%            Omit SensorObj if absent
%          * varargin is pairs of ...,key,val,... where the following keys
%            are availble:
%            'FocusGuess' - Best focus guess value.
%                   If vector then this is the best focus value for each
%                   camera.
%                   Default is 23650. %% TODO: maybe the current focus?
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
%            'SeveralPositions' - FIXME add description
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
%            .BestFocVal  - Best fit focus value.
%            .Az          - Mount Az [deg]
%            .Alt         - Mount Alt [deg]
%            .AM          - Mount airmass []
% By: Eran Ofek          April 2020 : rev Enrico Segre August 2021
% Example: [FocRes] = Unit.focusLoop(1) 

MountObj=UnitObj.Mount;
CamObj=UnitObj.Camera{itel};
FocObj=UnitObj.Focuser{itel};
SensObj=[]; % to be decided once we include sensors

PlotMarker    = 'o';
PlotMinMarker = 'p';

effA=CamObj{1}.classCommand('effective_area'); % this is maybe only for QHYccd?
CenterPos=floor([effA.syEff,effA.sxEff]/2);
Theta     = (0:60:300).';
DefSeveralPositions = [CenterPos; CenterPos + 2000.*[cosd(Theta), sind(Theta)]];

InPar = inputParser;
addOptional(InPar,'FocusGuess',26000);  
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
addOptional(InPar,'PixScale',1.25);  % "/pix
addOptional(InPar,'Plot',true);
parse(InPar,varargin{:});
InPar = InPar.Results;

if ~isempty(InPar.SeveralPositions)
    InPar.ImageHalfSize = [];
    Nsp=numel(SeveralPositions);
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
FocusGuess  = InPar.FocusGuess + (AmbTemp - InPar.FocusGuessTemp).*InPar.FocusTempGrad;

% backlash direction: + means the start value is above the best guess value
BacklashDir = sign(InPar.BacklashFocus);
% Start pos is a vector of length Ncam % TODO: now it is a scalar...
StartFocus    = InPar.FocusGuess + InPar.BacklashFocus;

% prepare a table of focus values to test for each camera
% Each column is the focus values for each camera.
FocusValCam = nan(Nfocus,Ncam);
for Icam=1:1:Ncam
    FocusValCam(:,Icam) = ((FocusGuess(Icam)-InPar.HalfRange): InPar.Step :...
                           (FocusGuess(Icam)+InPar.HalfRange)).';
end
    
%Limits = [FocusGuess - InPar.HalfRange, FocusGuess + InPar.HalfRange];

%PosVec = (Limits(1):InPar.Step:Limits(2)).';
if BacklashDir>0
    FocusValCam = flipud(FocusValCam);    
else
    % no need to reverse PosVec
end

% End argument parsing and preliminaries, operate

% go to focus start position (checking that we are ok to start)
UnitObj.readyToExpose(itel,true);
for Icam=itel
    FocObj(Icam).classCommand(sprintf('Pos=%d;', StartFocus)); % TODO vector StartFocus
end
UnitObj.readyToExpose(itel,true);

FocVal = nan(Nfocus,Nsp,2);
for Ifocus=1:Nfocus
    for Icam=1:Ncam
        UnitObj.report('Focuser %d -- at position: %f (#%d out of %d)',...
                        Icam,FocusValCam(Ifocus,Icam), Ifocus, Nfocus);
    end
    
    % set all focusers
    for Icam=1:1:Ncam
        FocObj(Icam).classCommand(sprintf('Pos=%d;',FocusValCam(Ifocus,Icam)));
    end
    % wait for all focusers
    UnitObj.readyToExpose(itel,true);
    
    % take one exposure with all cameras
    UnitObj.takeExposure(itel,InPar.ExpTime);
    % wait for all cameras
    UnitObj.readyToExpose(itel,true,InPar.ExpTime+10); % TODO: abort if failed
    
    % measure FWHM for each camera
    for Icam=1:1:Ncam
        if isa(CamObj(Icam),'obs.camera')
            FocVal(Ifocus,:,Icam)=imageFocus(CamObj(Icam).LastImage,...
                                             InPar.ImageHalfSize,...
                                             InPar.SigmaVec, InPar.PixScale,...
                                             InPar.SeveralPositions);
        elseif isa(CamObj(Icam),'obs.remoteClass')
            % do this in slave for remote cameras: construct command...
            focuscommand=['imageFocus(' CamObj(Icam).RemoteName '.LastImage,'...
                          sprintf('%g,%s,%g,%s);', InPar.ImageHalfSize, ...
                          mat2str(InPar.SigmaVec), InPar.PixScale, ...
                          mat2str(InPar.SeveralPositions) ) ];
            FocVal(Ifocus,:,Icam)=CamObj(Icam).Messenger.query(focuscommand);
        else
            % do nothing, safeguard
        end
    end
    
    if InPar.Plot
        % clear all matlab plots
        %close all    
        for Icam=1:1:Ncam           
            H=plot(FocusValCam(Ifocus,Icam),FocVal(Ifocus,Icam),'ko',...
                   'MarkerFaceColor','r');
            H.Marker          = PlotMarker;
            H.Color           = Colors(Icam,:);
            H.MarkerFaceColor = Colors(Icam,:);
            if Ifocus==1
                H = xlabel('Focus position');
                H.FontSize = 18;
                H.Interpreter = 'latex';
                H = ylabel('FWHM [arcsec]');
                H.FontSize = 18;
                H.Interpreter = 'latex';
                hold on;
            end
        end
        drawnow
    end
    
end

Res.PosVec      = FocusValCam;
Res.FocVal      = FocVal;

%Extram = Util.find.find_local_extramum(flipud(PosVec),flipud(FocVal));
FullFocVal=nan(Nsp,Ncam);
for Isp=1:1:Nsp
    for Icam=1:1:Ncam
        FullPosVec = (min(Res.PosVec(:,Icam)):1:max(Res.PosVec(:,Icam)))';
        FullFocVal(Isp,Icam) = interp1(Res.PosVec(:,Icam),Res.FocVal(:,Isp,Icam),FullPosVec,'makima');
        [Res.BestFocFWHM(Isp,Icam),MinInd] = min(FullFocVal(Isp,Icam));
        Res.BestFocVal(Isp,Icam) = FullPosVec(MinInd);
    end
end

UnitObj.report(sprintf('Best focus value  : %f\n',Res.BestFocVal));
UnitObj.report(sprintf('FWHM at best focus: %f\n',Res.BestFocFWHM));


if InPar.Plot
    for Icam=1:1:Ncam
        H=plot(Res.BestFocVal,Res.BestFocFWHM,'rp','MarkerFaceColor','r');
        H.Marker          = PlotMinMarker;
        H.Color           = Colors(Icam,:);
        H.MarkerFaceColor = Colors(Icam,:);
    end
    drawnow
end

% move up (start position to avoid backlash)
for Icam=1:1:Ncam
    FocObj(Icam).Pos = StartFocus(Icam);
end
UnitObj.readyToExpose(itel,true); % here we could check only focusers

% go to best focus
fprintf('Set focus to best value\n');
for Icam=1:1:Ncam
    FocObj(Icam).Pos = Res.BestFocVal(Icam);
end
UnitObj.readyToExpose(itel,true); % here we could check only focusers

Res.Az  = MountObj.Az;
Res.Alt = MountObj.Alt;
Res.AM  = celestial.coo.hardie(pi./2 - Res.Alt.*pi/180);
