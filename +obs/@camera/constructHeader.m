function [HeaderCell,Info]=constructHeader(CameraObj)
    % Construct image header for Camera object
    % Output  : - A 3 column cell array with header for image
    %           - A structure with all the header key and vals.


    RAD = 180./pi;

    % Image related information
    %    12345678
    Info.NAXIS    = ndims(CameraObj.LastImage);
    SizeImIJ      = size(CameraObj.LastImage);
    Info.NAXIS1   = SizeImIJ(2);
    Info.NAXIS2   = SizeImIJ(1);
    Info.BITPIX   = -32;
    Info.BZERO    = 0.0;
    Info.BSCALE   = 1.0;
    Info.IMTYPE   = CameraObj.ImType;
    Info.OBJECT   = CameraObj.Object;            
    % Gain
    Key   = 'GAIN';
    Field = Key;
    if isfield(CameraObj.ConfigStruct,Field)
        Info.(Key)     = CameraObj.ConfigStruct.(Field);
    else
        Info.(Key)     = NaN;
    end

    % internal gain
    Info.INTGAIN  = CameraObj.Gain;

    % Read noise
    Key   = 'READNOI';
    Field = Key;
    if isfield(CameraObj.ConfigStruct,Field)
        Info.(Key)     = CameraObj.ConfigStruct.(Field);
    else
        Info.(Key)     = NaN;
    end

    % Dark current
    Key   = 'DARKCUR';
    Field = Key;
    if isfield(CameraObj.ConfigStruct,Field)
        Info.(Key)     = CameraObj.ConfigStruct.(Field);
    else
        Info.(Key)     = NaN;
    end
    %
    Info.BINX     = CameraObj.Binning(1);
    Info.BINY     = CameraObj.Binning(2);
    % 
    Info.CamNum   = CameraObj.CameraNumber;
    Info.CamPos   = CameraObj.CameraPos;
    Info.CamType  = CameraObj.CameraType;
    Info.CamModel = CameraObj.CameraModel;
    Info.CamName  = CameraObj.CameraName;
    % Mount informtaion
    if Util.struct.isfield_notempty(CameraObj.ConfigMount,'MountNumber')
        Info.MountNum = CameraObj.ConfigMount.MountNumber;
    else
        Info.MountNum = NaN;
    end

    % OBSERVER
    %ORIGIN
    %OBSNAME
    %OBSPLACE


    if Util.struct.isfield_notempty(CameraObj.ConfigMount,'ObsLon')
        Info.ObsLon = CameraObj.ConfigMount.ObsLon;
    else
        Info.ObsLon = NaN;
    end
    if Util.struct.isfield_notempty(CameraObj.ConfigMount,'ObsLat')
        Info.ObsLat = CameraObj.ConfigMount.ObsLat;
    else
        Info.ObsLat = NaN;
    end
    if Util.struct.isfield_notempty(CameraObj.ConfigMount,'ObsHeight')
        Info.ObsHeight = CameraObj.ConfigMount.ObsHeight;
    else
        Info.ObsHeight = NaN;
    end

    %Info.JD       = juliandate(CameraObj.Handle.LastImageTime);
    Info.JD       = 1721058.5 + CameraObj.Handle.TimeStartLastImage;
    %Info.ExpTime  = CameraObj.Handle.LastImageExpTime;
    Info.ExpTime  = CameraObj.ExpTime;
    Info.LST      = celestial.time.lst(Info.JD,Info.ObsLon./RAD,'a').*360;  % deg
    DateObs       = convert.time(Info.JD,'JD','StrDate');
    Info.DATE_OBS = DateObs{1};


    % get RA/Dec - Mount equinox of date
    Info.M_RA     = commCommand(CameraObj, CameraObj.HandleMount,'RA');

    Info.M_DEC    = commCommand(CameraObj, CameraObj.HandleMount,'Dec');
    Info.M_HA     = convert.minusPi2Pi(Info.LST - Info.M_RA);
    % RA/Dec - mount J2000
    Info.M_JRA    = commCommand(CameraObj, CameraObj.HandleMount,'j2000_RA');
    Info.M_JDEC   = commCommand(CameraObj, CameraObj.HandleMount,'j2000_Dec');
    Info.M_HA     = convert.minusPi2Pi(Info.LST - Info.M_JRA);
    % RA/Dec - J2000 camera center
    if ~isempty(CameraObj.ConfigStruct)
        if Util.struct.isfield_notempty(CameraObj.ConfigStruct,'MountCameraDist') && ...
                Util.struct.isfield_notempty(CameraObj.ConfigStruct,'MountCameraPA')
            [Info.DEC, Info.RA] = reckon(Info.M_JDEC,...
                                     Info.M_JRA,...
                                     CameraObj.ConfigStruct.MountCameraDist,...
                                     CameraObj.ConfigStruct.MountCameraPA,'degrees');
        else
            Info.RA  = Info.M_JDEC;
            Info.DEC = Info.M_JRA;
        end
        Info.RA = mod(Info.RA,360);
    else
        Info.RA  = Info.M_JDEC;
        Info.DEC = Info.M_JRA;
    end



    Info.AZ       = commCommand(CameraObj, CameraObj.HandleMount,'Az');
    Info.ALT      = commCommand(CameraObj, CameraObj.HandleMount,'Alt');
    Info.EQUINOX  = 2000.0;
    Info.AIRMASS  = celestial.coo.hardie(pi./2-Info.ALT./RAD);
    Info.TRK_RA   = commCommand(CameraObj, CameraObj.HandleMount,'trackingSpeedRA')./3600;  % [arcsec/s]
    Info.TRK_DEC  = commCommand(CameraObj, CameraObj.HandleMount,'trackingSpeedDec')./3600;  % [arcsec/s]

    % focuser information
    Info.FOCUS    = commCommand(CameraObj, CameraObj.HandleFocuser,'Pos');
    Info.PRVFOCUS = commCommand(CameraObj, CameraObj.HandleFocuser,'LastPos');



    % struct to HeaderCell + comments
    % Input : Info, CommentsDB
    CommentsDB = CameraObj.ConfigHeader;

    FN  = fieldnames(Info);
    Nfn = numel(FN);
    if ~isempty(CommentsDB)
        CommentFN = fieldnames(CommentsDB);
    end
    HeaderCell = cell(Nfn,3);
    for Ifn=1:1:Nfn
        HeaderCell{Ifn,1} = upper(FN{Ifn});
        HeaderCell{Ifn,2} = Info.(FN{Ifn});
        if ~isempty(CommentsDB)
            % get comment
            Ind = find(strcmpi(FN{Ifn},CommentFN));
            if ~isempty(Ind)
                HeaderCell{Ifn,3} = CommentsDB.(CommentFN{Ind});
            end
        end
    end

end
