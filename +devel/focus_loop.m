function [Res] = focus_loop(CamObj,MountObj,FocObj)
% Example: [FocRes] = devel.focus_loop(C,M,F)

%ExpTime = 1;
StartPos = 23800;
FocusGuess = 23600;

PlotMarker = 'o';
PlotMinMarker = 'p';
PlotColor     = 'r';

HalfRange  = 120;
Step       = 40;
Limits = [FocusGuess - HalfRange, FocusGuess + HalfRange];
%Step   = 30;

RangeY = (3001:4000);
RangeX = (4001:5000);

PixScale = 1.21;

PosVec = (Limits(1):Step:Limits(2)).';
PosVec = flipud(PosVec);

Npos   = numel(PosVec);

SigmaVec = logspace(0,1,25).';
SigmaVec = [0.1; SigmaVec];
switch lower(FocObj.Status)
    case 'unknown'
        error('Focus status unknown');
end

    
FocObj.Pos = StartPos;
FocObj.waitFinish;


FocVal = nan(Npos,1);
for Ipos=1:1:Npos
    [PosVec(Ipos), Ipos, Npos]
    
    FocObj.Pos = PosVec(Ipos);
    FocObj.waitFinish;
    
    CamObj.takeExposure;
    CamObj.waitFinish;

%    ds9(CamObj.lastImage);
    
%    devel.saveim(CamObj,MountObj,FocObj,'focus');
    
    % calculate focus:
    %Image = single(CamObj.lastImage(RangeY,RangeX));
    Image = single(imUtil.image.trim(CamObj.CamHn.lastImage,[800 800],'center'));
    SN = imUtil.filter.filter2_snBank(Image,[],[],@imUtil.kernel2.gauss,SigmaVec);
    [BW,Pos,MaxIsn]=imUtil.image.local_maxima(SN,1,5);
    
    % remove sharp objects
    Pos = Pos(Pos(:,4)~=1,:);
    if isempty(Pos)
        FocVal(Ipos) = NaN;
    else
        % instead one can check if the SN improves...
        
        FocVal(Ipos) = 2.35.*PixScale.*SigmaVec(mode(Pos(Pos(:,3)>50,4),'all'));
    end
    
    % clear all matlab plots
    %close all
    H=plot(PosVec(Ipos),FocVal(Ipos),'ko','MarkerFaceColor','k');
    H.Marker          = PlotMarker;
    H.Color           = PlotColor;
    H.MarkerFaceColor = PlotColor;
    
    if Ipos==1
        H = xlabel('Focus position');
        H.FontSize = 18;
        H.Interpreter = 'latex';
        H = ylabel('FWHM [arcsec]');
        H.FontSize = 18;
        H.Interpreter = 'latex';
        
        hold on;
    end
    
    CamObj.CamHn.lastImage = [];
    
end
    


Res.PosVec      = PosVec;
Res.FocVal      = FocVal;

%Extram = Util.find.find_local_extramum(flipud(PosVec),flipud(FocVal));
FullPosVec = (min(Res.PosVec):1:max(Res.PosVec))';
FullFocVal = interp1(Res.PosVec,Res.FocVal,FullPosVec,'makima');
[Res.BestFocFWHM,MinInd] = min(FullFocVal);
Res.BestFocVal = FullPosVec(MinInd);


fprintf('Best focus value  : %f\n',Res.BestFocVal);
fprintf('FWHM at best focus: %f\n',Res.BestFocFWHM);


% deal with multiple extrima - select global minima
%[~,Iextram] = min(Extram(:,2));
%Extram      = Extram(Iextram,:);

%Res.BestFocVal  = Extram(1);
%Res.BestFocFWHM = Extram(2);

H=plot(Res.BestFocVal,Res.BestFocFWHM,'rp','MarkerFaceColor','r')
H.Marker          = PlotMinMarker;
H.Color           = PlotColor;
H.MarkerFaceColor = PlotColor;

% move up (startp position to avoid backlash)
FocObj.Pos = StartPos;
while ~strcmp(FocObj.Status,'idle')
    pause(1);
end

% go to best focus
fprintf('Set focus to best value\n');
FocObj.Pos = Res.BestFocVal;
FocObj.waitFinish;

    


% % fit parabola
%MidFocRange = mean(Limits);
% PolyPar = polyfit(PosVec-MidFocRange,FocVal,2)
% 
% BestFocVal  = -PolyPar(2)./(2.*PolyPar(1));
% BestFocFWHM = polyval(PolyPar, BestFocVal);
% BestFocVal  = MidFocRange - BestFocVal;
% 
% 





