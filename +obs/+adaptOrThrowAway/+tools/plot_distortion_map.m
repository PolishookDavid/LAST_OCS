function plot_distortion_map(MountHA,MountDec,AstHA,AstDec)
%


RAD = 180./pi;


InPar = inputParser;
addOptional(InPar,'Lon',34.8125);  
addOptional(InPar,'AstRA',[]);  
addOptional(InPar,'AstHA',[]);  
addOptional(InPar,'AstDec',[]);  
addOptional(InPar,'AstJD',[]);  
addOptional(InPar,'ValidRangeHA',[-120 120]);  
addOptional(InPar,'ValidRangeDec',[-60 90]);  

addOptional(InPar,'Verbose',true);
addOptional(InPar,'Plot',true);
parse(InPar,varargin{:});
InPar = InPar.Results;

if isempty(InPar.AstHA)
    % attempt calculating HA from RA and JD
    if isempty(InPar.AstRA) || isempty(InPar.AstJD)
        error('If AstHA is not provided AstRA and AstJD must be provided');
    end
    

    LST = celestial.time.lst(InPar.AstJD,InPar.Lon./RAD,'a').*360;  % deg
    HA  = LST - InPar.AstRA;
    HA  = mod(HA,360);
    HA(HA>180) = HA(HA>180) - 360;
    InPar.AstHA = HA;
end


FlagValid = MountHA>InPar.ValidRangeHA(1) & MountHA<InPar.ValidRangeHA(2) & ...
            MountDec>InPar.ValidRangeDec(1) & MountDec<InPar.ValidRangeHA(2) & ...
            ~isnan(InPar.AstHA) & ~isnan(InPar.AstDec);
        
MountHA  = MountHA(FlagValid);
MountDec = MountDec(FlagValid);
InPar.AstHA    = InPar.AstHA(FlagValid);
InPar.AstDec   = InPar.AstDec(FlagValid);

F = scatteredInterpolant(InPar.AstHA,InPar.AstDec,(InPar.AstHA-MountHA));

VecHA = [-120:10:120].';
VecDec = [-40:10:80].';
[MatHA,MatDec] = meshgrid(VecHA,VecDec);

Map = F(MatHA,MatDec);
surface(VecHA,VecDec,Map)


