function Aux=pointingCorrection(MountObj,MetData,TelOffset,JD)
% compute the corrected J coordinates from the mount own ones,
% considering nutation, aberration, refraction and pointing model
%
% Input: MetData - a structure containing the fields
%                     MetData.Wave (default =5000; % Å)
%                     MetData.Temp (default =15;   % °C)
%                     MetData.P    (default =760;  % mmHg)
%                     MetData.Pw   default( =8;    % mmHg)
%
%        TelOffset - [HA offset, Dec offset] of the the telescope
%                       in degrees(deault [0,0])
%
%        JD - julian day (default:  of now)
%
% Output: a structure with fields
%                           RA_App
%                           HA_App
%                           Dec_App
%                           RA_AppDist
%                           HA_AppDist
%                           Dec_AppDist
%                           Alt_App
%                           Az_App
%                           RA_J2000
%                           Dec_J2000
%                           HA_J2000
%                           AirMass


if isempty(MountObj.INPOP)
    MountObj.reportError('No INPOP solar system ephemerides installed, cannot execute')
    Aux=[];
    return
end

if ~exist('MetData','var') || isempty(MetData)
    MetData.Wave = 5000;
    MetData.Temp = 15;
    MetData.P    = 760;
    MetData.Pw   = 8;
end

if ~exist('TelOffset','var') || isempty(TelOffset)
    TelOffset=[0,0];
end

if ~exist('JD','var')
    JD= 1721058.5 + now;
end

GeoPos = MountObj.MountPos;
GeoPos(1:2)=GeoPos(1:2) * pi/180;

[OutRA, OutDec, Alt, Refraction, Aux] = celestial.convert.apparent_toJ2000(...
    MountObj.RA, MountObj.Dec, JD,...
    'InUnits','deg','Epoch',2000,'OutUnits','deg','OutEquinox',[],...
    'OutEquinoxUnits','JD','OutMean',false,...
    'PM_RA',0,'PM_Dec',0,'Plx',1e-2,'RV',0,'INPOP',MountObj.INPOP,...
    'GeoPos',GeoPos,'TypeLST','m',...
    'ApplyAberration',true,'ApplyRefraction',true,...
    'Wave',MetData.Wave,'Temp',MetData.Temp,'Pressure',MetData.P,...
    'Pw',MetData.Pw,...
    'ShiftRA',TelOffset(1),'ShiftDec',TelOffset(2),...
    'ApplyDistortion',true,...
    'InterpHA',MountObj.PointingModel.InterpHA,...
    'InterpDec',MountObj.PointingModel.InterpDec);
