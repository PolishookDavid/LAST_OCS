function [Res] = focus_loop(CamObj,MountObj,FocObj,SensObj,varargin)
% Execute focus loop on LAST telescope
% Package: +obs.util.tools
% Description: Obtain an image with each focus value, and measure the FWHMF
%              as a function of focus. Interpolate the best focus value.
%              The focus loop assumes that there is a backlash in the
%              system. In the begining, the focus is set to StartPos
%              (In LAST StartPos is higher than the guess focus value).
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
%                   Default is 23650.
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
%                   temperature [focus value/1 C].
%                   Default is 0.
%            'BacklashPos' - A focus value relative to the estimated best
%                   focus value (- below / + above)
%                   from which to start moving, in order to deal with
%                   backlash. 
%                   The sign of this argument defines the direction of the
%                   backlash. Default is 150.
%            'ExpTime'  - Exposure time. Default is 5 sec.
%            'NimExp'   - Number of images per exposure. Default is 1.
%            'ImageHalfSize' - Half size of sub image in which to measure
%                   the focus. If empty use full image. Default is 1000.
%            'SigmaVec' - Vector of gaussian kernel sigma-width (template
%                   bank) with wich to cross-correlate the image.
%                   This will define the range and resolution of the
%                   measured seeing.
%                   Default is [0.1, logspace(0,1,25)].'.
%            'PixScale' - ["/pix]. Default is 1.25 "/pix.
%            'Verbose' - Default is true.
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
% By: Eran Ofek          April 2020
% Example: [FocRes] = obs.util.tools.focus_loop(C,M,F,S) 

RAD = 180./pi;

PlotMarker    = 'o';
PlotMinMarker = 'p';


InPar = inputParser;
addOptional(InPar,'FocusGuess',35000);  
addOptional(InPar,'HalfRange',250);  
addOptional(InPar,'Step',50);  
addOptional(InPar,'FocusGuessTemp',25);  
addOptional(InPar,'FocusTempGrad',0);  
addOptional(InPar,'BacklashPos',200);  
addOptional(InPar,'ExpTime',3);  
addOptional(InPar,'NimExp',1);  
addOptional(InPar,'ImageHalfSize',1000);  % If [] use full image
addOptional(InPar,'SigmaVec',[0.1, logspace(0,1,25)].');
addOptional(InPar,'PixScale',1.25);  % "/pix
addOptional(InPar,'Verbose',true);
addOptional(InPar,'Plot',true);
parse(InPar,varargin{:});
InPar = InPar.Results;

% deal with hardward objects
warning('Add here treatment of OCS class / multiple cameras per process');

% number of cameras and focusers
Ncam = numel(CamObj);
Nfoc = numel(FocObj);

if InPar.Plot
    Colors = plot.generate_colors(Ncam);
end

% number of focus steps
Nstep = floor(InPar.HalfRange./InPar.Step).*2 + 1;
% adapt HalfRange accoring to number of steps
InPar.HalfRange = InPar.Step.*(Nstep-1).*0.5;


if Ncam~=Nfoc
    error('Number of cameras mus be equal to the number of focusers');
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
FocusGuess  = InPar.FocusGuess + (AmbTemp - InPar.FocusGuessTemp).*InPar.FocusTempGrad;

% backlash direction: + means the start value is above the best guess value
BacklashDir = sign(InPar.BacklashPos);
% Start pos is a vector of length Ncam
StartPos    = InPar.FocusGuess + InPar.BacklashPos;


% prepare a table of focus values to test for each camera
% Each column is the focus values for each camera.
FocusValCam = nan(Nstep,Ncam);
for Icam=1:1:Ncam
    FocusValCam(:,Icam) = ((FocusGuess(Icam) - InPar.HalfRange):InPar.Step:(FocusGuess(Icam) + InPar.HalfRange)).';
end
    
%Limits = [FocusGuess - InPar.HalfRange, FocusGuess + InPar.HalfRange];

%PosVec = (Limits(1):InPar.Step:Limits(2)).';
if BacklashDir>0
    FocusValCam = flipud(FocusValCam);    
else
    % no need to reverse PosVec
end


switch lower(FocObj.Status)
    case 'unknown'
        error('Focus status unknown');
end

% go to focus start position 
for Icam=1:1:Ncam
    FocObj(Icam).Pos = StartPos(Icam);
end
for Icam=1:1:Ncam
    FocObj(Icam).waitFinish;
end


% set exposure time
CamObj.ExpTime = InPar.ExpTime;

FocVal = nan(Nstep,2);

Cont = true;
Ipos = 0;
while Cont
    Ipos = Ipos+1;
    
    
    if InPar.Verbose
        for Icam=1:1:Ncam
            fprintf('Camera %d -- Testing focus position: %f (number %d out of %d)',Icam,FocusValCam(Ipos,Icam), Ipos, Nstep);
        end
    end
    
    % set all focusers
    for Icam=1:1:Ncam
        FocObj(Icam).Pos = FocusValCam(Ipos,Icam);
    end
    % wait for all focusers
    for Icam=1:1:Ncam
        FocObj(Icam).waitFinish;
    end
    
    % take exposures in all cameras
    for Icam=1:1:Ncam
        CamObj(Icam).takeExposure;
    end
    % wait for all cameras
    for Icam=1:1:Ncam
        CamObj(Icam).waitFinish;
    end
     
    % measure FWHM for each camera
    for Icam=1:1:Ncam
        
        if isempty(InPar.ImageHalfSize)
            Image = single(CamObj(Icam).LastImage);
        else
            Image = single(imUtil.image.trim(CamObj(Icam).LastImage,InPar.ImageHalfSize.*ones(1,2),'center'));
        end
        
        % filter image with filter bandk of gaussians with variable width
        SN = imUtil.filter.filter2_snBank(Image,[],[],@imUtil.kernel2.gauss,InPar.SigmaVec);
        [BW,Pos,MaxIsn]=imUtil.image.local_maxima(SN,1,5);

        % remove sharp objects
        Pos = Pos(Pos(:,4)~=1,:);
        if isempty(Pos)
            FocVal(Ipos) = NaN;
        else
            % instead one can check if the SN improves...
            FocVal(Ipos,Icam) = 2.35.*InPar.PixScale.*InPar.SigmaVec(mode(Pos(Pos(:,3)>50,4),'all'));
        end
    end
    
    
    
    if InPar.Plot
        % clear all matlab plots
        %close all    
        for Icam=1:1:Ncam
            
            H=plot(FocusValCam(Ipos,Icam),FocVal(Ipos,Icam),'ko','MarkerFaceColor','r');
            H.Marker          = PlotMarker;
            H.Color           = Colors(Icam,:);
            H.MarkerFaceColor = Colors(Icam,:);

            if Ipos==1
                H = xlabel('Focus position');
                H.FontSize = 18;
                H.Interpreter = 'latex';
                H = ylabel('FWHM [arcsec]');
                H.FontSize = 18;
                H.Interpreter = 'latex';

                hold on;
            end
        end
        %CamObj.LastImage = [];
    end
    
    if Ipos>=Nstep || exist('~/abort_focus','file')>0
        Cont = false;
    end
        

end
    


Res.PosVec      = FocusValCam;
Res.FocVal      = FocVal;

%Extram = Util.find.find_local_extramum(flipud(PosVec),flipud(FocVal));
for Icam=1:1:Ncam
    FullPosVec = (min(Res.PosVec(:,Icam)):1:max(Res.PosVec(:,Icam)))';
    FullFocVal = interp1(Res.PosVec(:,Icam),Res.FocVal(:,Icam),FullPosVec,'makima');
    [Res.BestFocFWHM(Icam),MinInd] = min(FullFocVal);
    Res.BestFocVal(Icam) = FullPosVec(MinInd);
end

if InPar.Verbose
    fprintf('Best focus value  : %f\n',Res.BestFocVal);
    fprintf('FWHM at best focus: %f\n',Res.BestFocFWHM);
end

if InPar.Plot
    for Icam=1:1:Ncam
        H=plot(Res.BestFocVal,Res.BestFocFWHM,'rp','MarkerFaceColor','r');
        H.Marker          = PlotMinMarker;
        H.Color           = Colors(Icam,:);
        H.MarkerFaceColor = Colors(Icam,:);
    end
end

% move up (startp position to avoid backlash)
for Icam=1:1:Ncam
    FocObj(Icam).Pos = StartPos(Icam);
end
for Icam=1:1:Ncam
    FocObj(Icam).waitFinish;
end

% go to best focus
fprintf('Set focus to best value\n');
for Icam=1:1:Ncam
    %Noam and David
    FocObj(Icam).Pos = Res.BestFocVal(Icam)+InPar.BaclashPos;
    FocObj(Icam).Pos = Res.BestFocVal(Icam);
end
for Icam=1:1:Ncam
    FocObj(Icam).waitFinish;
end

Res.Az  = MountObj.Az;
Res.Alt = MountObj.Alt;
Res.AM  = celestial.coo.hardie(pi./2 - Res.Alt./RAD);
    



