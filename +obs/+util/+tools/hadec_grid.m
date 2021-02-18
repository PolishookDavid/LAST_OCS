function List=hadec_grid(varargin)
% Prepare an Az/Alt HA/Dec grid over the celestial sphere
% Package: +obs.util.tools
% Input  : * Pairs of ...,key,val,... arguments. Possible keywords are:
%            'NstepGC' - Number of steps over great circle.
%                   Default is 20.
%            'MinAM'   - Minimum airmass. Default is 2.
%            'Lat'     - Observatory Latitude [deg].
%                   Default is 31.9.
%            'AzAltLimit' - Az/Alt exclusion map [Az, Alt] in deg.
%                   Default is [250 0; 251 70; 315 70; 320 0].
% Output : - A structure containing the following fields:
%            .HA - HA in deg
%            .Dec - Dec in deg
%            .Az - Az in deg
%            .Alt - Alt in deg
%            .AM  - Hardie airmass.
%      By : Eran Ofek              Aug 2020
% Example : List=obs.util.tools.hadec_grid

RAD = 180./pi;

InPar = inputParser;
addOptional(InPar,'NstepGC',10);  % default is image center
addOptional(InPar,'MinAM',2);  % default is image center
addOptional(InPar,'Lat',31.9);  % [deg]
addOptional(InPar,'AzAltLimit',[0 20; 90 20; 180 20; 270 20; 360 20]);  % [deg]

parse(InPar,varargin{:});
InPar = InPar.Results;



[TileList] = celestial.coo.tile_the_sky(InPar.NstepGC,ceil(InPar.NstepGC.*0.5));
Az  = TileList(:,1);
Alt = TileList(:,2);
% airmass
AM   = celestial.coo.hardie(pi./2-Alt);
Flag = AM<InPar.MinAM;

if ~isempty(InPar.AzAltLimit)
    AltLimit = interp1(InPar.AzAltLimit(:,1)./RAD,InPar.AzAltLimit(:,2)./RAD,Az,'linear',0);
    Flag     = Flag & Alt>AltLimit;
end
Az   = Az(Flag);
Alt  = Alt(Flag);
AM   = AM(Flag);


% convert to HA/Dec
[HA,Dec] = celestial.coo.azalt2hadec(Az,Alt,InPar.Lat./RAD,'rad');

List.HA  = HA.*RAD;
List.Dec = Dec.*RAD;
List.Az  = Az.*RAD;
List.Alt = Alt.*RAD;
List.AM  = AM;




