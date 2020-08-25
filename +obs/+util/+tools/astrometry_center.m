function Res=astrometry_center(FileName,varargin)
% Quick RA/Dec of the image center using astrometric solution
% Package: +obs.util.tools
% Description: Design for quick astrometry of the center of the field of
%              view only, including two iterations to improves solution.
% Input  : - FileName, imCl image, SIM image, or a matrix containing the
%            image.
%          * Pairs of ...,key,val,... arguments. Possible keywords are:
%            'CenterXY' - Default is [] (i.e., use image center).
%            'HalfSize' - Half size in pixels on which to solve astrometry.
%                   Default is 1000.
%            'RA' - J2000.0 R.A. [radians].
%            'Dec' - J2000.0 Dec. [radians].
%            'Scale' - Scale. Default is 1.25"/pix.
%            'JD'    - JD. Default is celestial.time.julday.
%            'SecondIter' - Perform second iteration. Default is true.
%            'Verbose' - Default is true.
% Output : - A structure containing the astrometric solution and the image
%            center (RA and Dec).
% Example: Res=obs.util.tools.astrometry_center(filename)


RAD = 180./pi;


InPar = inputParser;
addOptional(InPar,'CenterXY',[]);  % default is image center
addOptional(InPar,'HalfSize',500);  % If empty, use the entire image
addOptional(InPar,'RA',[]);  % [rad]
addOptional(InPar,'Dec',[]);  % [rad]
addOptional(InPar,'Scale',1.25);  % [arcsec/pix]
addOptional(InPar,'JD',[]);
addOptional(InPar,'SecondIter',false);  
addOptional(InPar,'Verbose',true);  
parse(InPar,varargin{:});
InPar = InPar.Results;


if ischar(FileName)
    S = FITS.read2sim(FileName);
else
    if isnumeric(FileName)
        S = SIM;
        S.Im = FileName;
        S = S.add_key({'JD',InPar.JD});
    elseif imCl.isimCl(FileName)
        S = SIM;
        S.Im = FileName.Im;
        S.Header = FileName.Header.Header;
    elseif SIM.issim(FileName)
        S = FileName;
    else
        error('Unknwon option');
    end
end

% currently the program uses SIM.
% will be modified to imCl in the future

if isempty(InPar.RA) || isempty(InPar.Dec)
    InPar.RA = S.getkey('RA');
    InPar.RA = cell2mat(InPar.RA)./RAD;
    InPar.Dec = S.getkey('DEC');
    InPar.Dec = cell2mat(InPar.Dec)./RAD;
    
end

if isempty(InPar.JD)
    InPar.JD  = S.get_value('JD');
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
                        'RefCat','GAIADR219',...
                        'RefCatMagRange',[9 18],...
                        'RCrad',2.0./RAD,...
                        'UseCase_TranC',{'affine',5},...
                        'BlockSize',[3000 3000],...
                        'SearchRangeX',[-7000 7000],...
                        'SearchRangeY',[-7000 7000]);


W = ClassWCS.populate(S);
[Res.CenterRA, Res.CenterDec] = xy2coo(W,CenterXY);
Res.CenterRA  = Res.CenterRA;  % [rad]
Res.CenterDec = Res.CenterDec;  % [rad]

if InPar.Verbose
    fprintf('Astrometry - 1st iteration\n');
    fprintf('Number of sources: %d\n',AstR.NsrcN);
    if isnan(AstR.AssymErr)
        RMS = AstR.MinAssymErr;
    else
        RMS = AstR.AssymErr;
    end
    fprintf('Assym. rms: %f [arcsec]\n',RMS.*3600);
end




% second iteration
if InPar.SecondIter
    
    [AstR,S] = astrometry(S,'RA',Res.CenterRA,...
                            'Dec',Res.CenterDec,...
                            'Scale',InPar.Scale,...
                            'RefCat','GAIADR219',...
                            'Flip',[1 1],...
                            'RefCatMagRange',[9 15],...
                            'RCrad',1.5./RAD,...
                            'BlockSize',[3000 3000],...
                            'SearchRangeX',[-3000 3000],...
                            'SearchRangeY',[-3000 3000]);
    
    W = ClassWCS.populate(S);
    [Res.CenterRA, Res.CenterDec] = xy2coo(W,CenterXY);
    Res.CenterRA  = Res.CenterRA;  % [rad]
    Res.CenterDec = Res.CenterDec;  % [rad]

    if InPar.Verbose
        fprintf('Astrometry - 2nd iteration\n');
        fprintf('Number of sources: %d\n',AstR.NsrcN);
        if isnan(AstR.AssymErr)
            RMS = AstR.MinAssymErr;
        else
            RMS = AstR.AssymErr;
        end
        fprintf('Assym. rms: %f [arcsec]\n',RMS.*3600);
    end                   
end


Res.TelRA    = InPar.RA;
Res.TelDec   = InPar.Dec;
Res.JD       = InPar.JD;
Res.AstR     = AstR;
Res.CenterXY = CenterXY;
Res.CCDSEC   = CCDSEC;
Res.Image    = S;

