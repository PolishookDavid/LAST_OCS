function [ResP,Res]=polarAlignOnline_polaris(C,M,varargin)
% *** Might still work with mastrolindo classes
% *** First two arguments are the handles to a camera and a mount object
% *** Designed to be run in the matlab session where the objects are
%     locally defined
%
% Perform polar alignment using the pole rotation method
% Package: +obs.util.tools
% Description: Use the 'rotate around polar axis method' to polar align
%               the mount. The mount is directed to the pole and rotated in
%               HA. In each HA an image is taken. The stars will circle the
%               mount pole, while the pole position will be solved
%               astrometrically. The required shifts in Az/Alt to polar
%               align the mount will be reported.
% Input  : - Camera object
%          - Mount object
%          * Pairs of ...,key,val,... arguments. Possible keywords are:
%            'VecHA' - Vector of HA on which to observe Polaris [deg].
%                   This list must contain HA 0. 
%                   Default is [-60:30:60].
%            'PoleDec' - Pole declination [deg]. Default is +89.9999
%            'PolarisRA' - Polaris J2000.0 R.A. [deg].
%                   Default is celestial.coo.convertdms([2 31 49.09],'H','d')
%            'PolarisDec' - Polaris J2000.0 Dec. [deg].
%                   Default is celestial.coo.convertdms([1 89 15 50.8],'D','d')
%            'PixScale' - Default is 1.25 "/pix.
%            'Xalong' - options are: 'ra','-ra','dec','-dec'
%                   Default is '-ra';
%            'Yalong' - options are: 'ra','-ra','dec','-dec'
%                   Default is 'dec';
%            'ExpTime' - Exposure time. Default is 1s.
% Output : - A structure containing required shifts of mount from celestial
%            pole.
%          - A structure with all the measured images.
% By: Eran Ofek                         Jul varargin={}2020
% Example: [ResP,Res]=obs.util.tools.auto_polar_align_pole(C,M)



RAD = 180./pi;
SEC_IN_DAY = 86400;

InPar = inputParser;
addOptional(InPar,'VecHA',[-60:30:60]);
addOptional(InPar,'PoleDec',+89.9999);
addOptional(InPar,'PolarisRA',celestial.coo.convertdms([2 31 49.09],'H','d'));  % deg
addOptional(InPar,'PolarisDec',celestial.coo.convertdms([1 89 15 50.8],'D','d'));  % deg
addOptional(InPar,'PixScale',1.251);  % "/pix
addOptional(InPar,'Xalong','-ra');   % 'ra','-ra','dec','-dec'
addOptional(InPar,'Yalong','dec');  % 'ra','-ra','dec','-dec'

addOptional(InPar,'ExpTime',3);
addOptional(InPar,'Verbose',true);  
addOptional(InPar,'Plot',true);  
addOptional(InPar,'MarkerPolaris','ro'); 
addOptional(InPar,'MarkerCelPole','bo'); 
addOptional(InPar,'MarkerMountPole','co'); 
addOptional(InPar,'MarkerSize',50); 
addOptional(InPar,'HalfSize',[]); 


parse(InPar,varargin{:});
InPar = InPar.Results;

if InPar.Verbose
    fprintf('Polar alignment (pole method)\n');
end


% set exposure time
C.ExpTime = InPar.ExpTime;



Lon = M.MountPos(1);
Lat = M.MountPos(2);

Nha = numel(InPar.VecHA);

S = SIM(Nha,1);
for Iha=1:1:Nha
    if InPar.Verbose
        fprintf('Setting to HA number %d of %d\n',Iha,Nha);
    end
    
    HA  = InPar.VecHA(Iha);
    Dec = InPar.PoleDec;
    
    JD  = celestial.time.julday;  % current UTC JD
    LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg

    RA  = LST - HA;
    RA  = mod(RA,360);

    %--- point telescope to RA/Dec ---
    if Iha==1
        M.Dec = Dec;
        %M.waitFinish;
        pause(10);
    end
    M.RA = RA;
    %M.waitFinish;
    pause(10);
    
    pause(1);
        
    % take exposure
    C.takeExposure;

    %--- wait for image ---
    C.waitFinish;
    FileName = C.LastImageName;

    
    %--- astrometry ---
    %S = FITS.read2sim(FileName);
    S(Iha) = FITS.read2sim(FileName);
    %S = trim_image(S,[3001 4000 3001 4000]);
    %S(Iha) = trim_image(S(Iha),[3001 4000 3001 4000]);
    
    ResAst = obs.util.tools.astrometry_center(S(Iha),'RA',RA./RAD,...
                                                       'Dec',Dec./RAD,...
                                                       'HalfSize',[]);
                                                       %'HalfSize',InPar.HalfSize);
%     ResAst = obs.util.tools.astrometry_center(FileName,'RA',RA./RAD,...
%                                                        'Dec',Dec./RAD,...
%                                                        'HalfSize',[]);                                               
    % store astrometric images in S                                         
    S(Iha) = ResAst.Image;
    ds9(S(Iha),1)
    pause(1);
    
    [Res(Iha).PolarisX, Res(Iha).PolarisY]=ds9.coo2xy(InPar.PolarisRA, InPar.PolarisDec);
    [Res(Iha).CelPoleX, Res(Iha).CelPoleY]=ds9.coo2xy(0, 90.*sign(InPar.PoleDec));
    Res(Iha).PolarisX = Res(Iha).PolarisX; % +3000;
    Res(Iha).PolarisY = Res(Iha).PolarisY; % +3000;
    Res(Iha).CelPoleX = Res(Iha).CelPoleX; % +3000;
    Res(Iha).CelPoleY = Res(Iha).CelPoleY; % +3000;
    
    % identify the [X,Y] position of Polaris in the images
    %W = ClassWCS.populate(S);
    %[Res(Iha).PolarisX, Res(Iha).PolarisY] = coo2xy(W,[InPar.PolarisRA, InPar.PolarisDec]./RAD);
    % identify the celestial pole
    %[Res(Iha).CelPoleX, Res(Iha).CelPoleY] = coo2xy(W,[0, 90.*sign(InPar.PoleDec)]./RAD);
    
    Res(Iha).HA  = HA;
    Res(Iha).RA  = RA;
    Res(Iha).Dec = Dec;
    Res(Iha).JD  = JD;
end

% go back to HA=0;
HA  = 0;
Dec = InPar.PoleDec;
JD  = celestial.time.julday;  % current UTC JD
LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg
RA  = LST - HA;
RA  = mod(RA,360);

%--- point telescope to RA/Dec ---
M.Dec = Dec;
%M.waitFinish;

M.RA = RA;
%M.waitFinish;
pause(10);


% fit a circle to the [X,Y] position of polaris in all the images.
% Find the radius of the circle and its center [X,Y] position.
X = [Res.PolarisX];
Y = [Res.PolarisY];
CircData = [X(:), Y(:)];
[BestCen,BestRad,BestRMS]=imUtil.util.fit.circ_fit(CircData,'plane');

if InPar.Plot
    CS = coadd(S);
    ds9(CS,2);
    % mark mount pole
    ds9.plot(BestCen(1),BestCen(2),InPar.MarkerMountPole,'Size',InPar.MarkerSize.*[1 1 0]);
    % mark polaris pointings over all images
    ds9.plot(X(:),Y(:),InPar.MarkerPolaris,'Size',InPar.MarkerSize.*[1 1 0]);
    % mark celestial pole on the HA=0 image
    Iha0 = find([Res.HA]==0);
    ds9.plot(Res(Iha0).CelPoleX,Res(Iha0).CelPoleY,InPar.MarkerCelPole,'Size',InPar.MarkerSize.*[1 1 0]);
   
end

% calc dist between mount pole and celestial pole (calculated -observed)
% (sign is plus the direction the mount need to move)
ResP.DX  = -BestCen(1) + Res(Iha0).CelPoleX;  % pix
ResP.DY  = -BestCen(2) + Res(Iha0).CelPoleY;  % pix
switch lower(InPar.Xalong)
    case 'ra'
        ResP.DAz  = ResP.DX.*InPar.PixScale./60;    % arcmin
    case '-ra'
        ResP.DAz  = -ResP.DX.*InPar.PixScale./60;    % arcmin
    case 'dec'
        ResP.DAlt = ResP.DX.*InPar.PixScale./60;    % arcmin
    case '-dec'
        ResP.DAlt = -ResP.DX.*InPar.PixScale./60;    % arcmin
    otherwise
        error('Unknown RAlong option');
end
switch lower(InPar.Yalong)
    case 'ra'
        ResP.DAz = ResP.DY.*InPar.PixScale./60;    % arcmin
    case '-ra'
        ResP.DAz = -ResP.DY.*InPar.PixScale./60;    % arcmin
    case 'dec'
        ResP.DAlt = ResP.DY.*InPar.PixScale./60;    % arcmin
    case '-dec'
        ResP.DAlt = -ResP.DY.*InPar.PixScale./60;    % arcmin
    otherwise
        error('Unknown RAlong option');
end


if InPar.Verbose
    fprintf('\n\n');
    fprintf('------------------------\n');
    fprintf('ds9 legend: \n');
    fprintf('    Marker Polaris %s\n',InPar.MarkerPolaris);
    fprintf('    Marker celestial pole %s\n',InPar.MarkerCelPole);
    fprintf('    Marker mount pole %s\n',InPar.MarkerMountPole);    
    fprintf('Shift the mount Az/Alt such that the celestial pole coincides with the mount pole\n');
    fprintf('Required delta X shift [pix]     : %f\n',ResP.DX);
    fprintf('Required delta Y shift [pix]     : %f\n',ResP.DY);
    if (ResP.DAz > 0)
       fprintf('Decrease Az by:  [arcmin] : %f\n',ResP.DAz);
    else
       fprintf('Increase Az by:  [arcmin] : %f\n',ResP.DAz);
    end
    if (ResP.DAlt > 0)
       fprintf('Decrease Alt by [arcmin]: %f\n',ResP.DAlt);
    else
       fprintf('Increase Alt by [arcmin]: %f\n',ResP.DAlt);
    end
end


    

