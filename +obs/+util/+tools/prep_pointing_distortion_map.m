function Res=prep_pointing_distortion_map(C,M,varargin)
% Prepare distortion maps by solving astrometry over a grid of coordinates
% Package: +obs.util.tools
% Description :
% Input  : - Camera object.
%          - Mount object.
%          * Pairs of ...,key,val,... arguments. Possible keywords are:
%            'NstepGC' - Number of steps over great circle.
%                   Default is 20.
%            'MinAM'   - Minimum airmass. Default is 2.
%            'AzAltLimit' - Az/Alt exclusion map [Az, Alt] in deg.
%                   Default is [250 0; 251 70; 315 70; 320 0].
%            'ExpTime' - Exposure time. Default is 5s.
%            'Verbose' - Default is true.
% Output : -
%     By : Eran Ofek                  Aug 2020
% Example: Res=obs.util.tools.prep_pointing_distortion_map(C,M);


RAD = 180./pi;

InPar = inputParser;
addOptional(InPar,'NstepGC',12);  % number of points along great circle
addOptional(InPar,'MinAM',2);  
addOptional(InPar,'AzAltLimit',[0 0; 1 45; 45 45; 46 0; 250 0; 251 70; 315 70; 320 0]);  % [deg]
addOptional(InPar,'ExpTime',5);  
addOptional(InPar,'Verbose',true);  
parse(InPar,varargin{:});
InPar = InPar.Results;




Lon = M.MountPos(1);  % deg
Lat = M.MountPos(2);  % deg

% select grid
Grid = obs.util.tools.hadec_grid('NstepGC',InPar.NstepGC,'MinAM',InPar.MinAM,'Lat',Lat,'AzAltLimit',InPar.AzAltLimit);


% set exposure time
C.ExpTime = InPar.ExpTime;

Ntarget = numel(Grid.HA);
for Itarget=1:1:Ntarget
    tic;
    
    
    HA  = Grid.HA(Itarget);
    Dec = Grid.Dec(Itarget);
    JD  = celestial.time.julday;  % current UTC JD
    LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg

    RA  = LST - HA;
    RA  = mod(RA,360);

    if InPar.Verbose
        fprintf('Target %d out of %d\n',Itarget,Ntarget);
        fprintf('RA  : %f\n',RA);
        fprintf('HA  : %f\n',HA);
        fprintf('Dec : %f\n',Dec);
    end
    
    Res(Itarget).TargetRA  = RA;
    Res(Itarget).TargetDec = Dec;
    Res(Itarget).TargetHA  = HA;
    Res(Itarget).JD        = JD;

    %--- point telescope to RA/Dec ---
    M.goto(RA,Dec);
    M.waitFinish;

    pause(1);

    %--- read actual telescope coordinates from mount
    Res(Itarget).MountRA  = M.RA;
    Res(Itarget).MountDec = M.Dec;
    Res(Itarget).MountHA  = M.HA;
  
    %--- take image ---
    C.takeExposure;

    %--- wait for image ---
    C.waitFinish;
    FileName = C.LastImageName;

    try
        %--- astrometry ---
        ResAst = obs.util.tools.astrometry_center(FileName,'RA',Res(Itarget).MountRA./RAD,...
                                                     'Dec',Res(Itarget).MountDec./RAD);
        % save results
        Res(Itarget).FileName    = FileName;
        Res(Itarget).AstR        = ResAst.AstR;
        Res(Itarget).AstAssymRMS = ResAst.AstR.AssymErr;
        Res(Itarget).AstRA       = ResAst.CenterRA;
        Res(Itarget).AstDec      = ResAst.CenterDec;
    
        
    end
    
    toc
end
