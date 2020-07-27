function Res=astrometry_center(FileName,varargin)
% Return the RA/Dec of the image center using astrometric solution
% 
% Input  : - FileName or a matrix of image
% Example: Res=obs.util.astrometry_center(filename)


RAD = 180./pi;


InPar = inputParser;
addOptional(InPar,'CenterXY',[]);  % default is image center
addOptional(InPar,'HalfSize',1000);  % If empty, use the entire image
addOptional(InPar,'RA',[]);  % [rad]
addOptional(InPar,'Dec',[]);  % [rad]
addOptional(InPar,'Scale',1.25);  % [arcsec/pix]
addOptional(InPar,'JD',celestial.time.julday);  % [arcsec/pix]

parse(InPar,varargin{:});
InPar = InPar.Results;


if ischar(FileName)
    S = FITS.read2sim(FileName);
else
    if isnumeric(FileName)
        S = SIM;
        S.Im = FileName;
        S = S.add_key({'JD',InPar.JD});
    elseif SIM.issim(FileName)
        S = FileName;
    else
        error('Unknwon option');
    end
end

if isempty(InPar.RA) || isempty(InPar.Dec)
    InPar.RA = S.get_value('RA')./RAD;
    %InPar.RA = cell2mat(RA)./RAD;
    InPar.Dec = S.get_value('DEC')./RAD;
    %InPar.Dec = cell2mat(Dec)./RAD;
end

if isempty(InPar.CenterXY)
    % get image center
    CenterXY = fliplr(size(S.Im)./2);
else
    CenterXY = InPar.CenterXY;
end

if isempty(InPar.HalfSize)
    % do nothing
    CCDSEC = [];
else
    CCDSEC = [CenterXY(1), CenterXY(1), CenterXY(2), CenterXY(2)] + [-InPar.HalfSize InPar.HalfSize -InPar.HalfSize InPar.HalfSize];
    CenterXY = [InPar.HalfSize, InPar.HalfSize] + 1; 
end
Res.CenterXY = CenterXY;

if ~isempty(CCDSEC)
    S = trim_image(S,CCDSEC);
end


%--- solve astrometry ---
%
S = mextractor(S);

[AstR,S] = astrometry(S,'RA',InPar.RA,...
                        'Dec',InPar.Dec,...
                        'Scale',InPar.Scale,...
                        'Flip',[1 1],...
                        'RefCatMagRange',[9 16],...
                        'RCrad',2./RAD,...
                        'BlockSize',[3000 3000],...
                        'SearchRangeX',[-6000 6000],...
                        'SearchRangeY',[-6000 6000]);
AstR.NsrcN     
AstR.AssymErr.*3600

W = ClassWCS.populate(S);
[Res.CenterRA, Res.CenterDec] = xy2coo(W,CenterXY);
Res.CenterRA  = Res.CenterRA;  % [rad]
Res.CenterDec = Res.CenterDec;  % [rad]

Res.AstR     = AstR;
Res.CenterXY = CenterXY;
Res.CCDSEC   = CCDSEC;
Res.Image    = S;

