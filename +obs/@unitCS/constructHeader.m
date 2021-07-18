function [HeaderCell,Info]=constructHeader(UnitObj,itel)
    % Construct image header for takes of the nth telescope
    % Input   : the telescope number 
    % Output  : - A 3 column cell array with header for image
    %           - A structure with all the header key and vals.

    CameraObj=UnitObj.Camera{itel};
    
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
    if isfield(CameraObj.Config,Field)
        Info.(Key)     = CameraObj.Config.(Field);
    else
        Info.(Key)     = NaN;
    end

    % internal gain
    Info.INTGAIN  = CameraObj.Gain;

    % Read noise
    Key   = 'READNOI';
    Field = Key;
    if isfield(CameraObj.Config,Field)
        Info.(Key)     = CameraObj.Config.(Field);
    else
        Info.(Key)     = NaN;
    end

    % Dark current
    Key   = 'DARKCUR';
    Field = Key;
    if isfield(CameraObj.Config,Field)
        Info.(Key)     = CameraObj.Config.(Field);
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
    Info.MountNum = UnitObj.Mount.Id;

    % OBSERVER
    %ORIGIN
    %OBSNAME
    %OBSPLACE


    if tools.struct.isfield_notempty(UnitObj.Mount.Config,'ObsLon')
        Info.ObsLon = UnitObj.Mount.Config.ObsLon;
    else
        Info.ObsLon = NaN;
    end
    if tools.struct.isfield_notempty(UnitObj.Mount.Config,'ObsLat')
        Info.ObsLat = UnitObj.Mount.Config.ObsLat;
    else
        Info.ObsLat = NaN;
    end
    if tools.struct.isfield_notempty(UnitObj.Mount.Config,'ObsHeight')
        Info.ObsHeight = UnitObj.Mount.Config.ObsHeight;
    else
        Info.ObsHeight = NaN;
    end

    %Info.JD       = juliandate(CameraObj.LastImageTime);
    Info.JD       = 1721058.5 + CameraObj.TimeStartLastImage;
    %Info.ExpTime  = CameraObj.LastImageExpTime;
    Info.ExpTime  = CameraObj.ExpTime;
    Info.LST      = celestial.time.lst(Info.JD,Info.ObsLon./RAD,'a').*360;  % deg
    DateObs       = convert.time(Info.JD,'JD','StrDate');
    Info.DATE_OBS = DateObs{1};

    

    % get RA/Dec - Mount equinox of date
    % This was conceived to query eventually a remote mount from a slave
    % unit. Rethink
    Info.M_RA     = obs.classCommand(UnitObj.Mount,'RA');

    Info.M_DEC    = obs.classCommand(UnitObj.Mount,'Dec');
    Info.M_HA     = convert.minusPi2Pi(Info.LST - Info.M_RA);
    % RA/Dec - mount J2000
    Info.M_JRA    = obs.classCommand(UnitObj.Mount,'j2000_RA');
    Info.M_JDEC   = obs.classCommand(UnitObj.Mount,'j2000_Dec');
    Info.M_HA     = convert.minusPi2Pi(Info.LST - Info.M_JRA);
    % RA/Dec - J2000 camera center
    if ~isempty(CameraObj.Config)
        if tools.struct.isfield_notempty(CameraObj.Config,'MountCameraDist') && ...
                tools.struct.isfield_notempty(CameraObj.Config,'MountCameraPA')
            [Info.DEC, Info.RA] = reckon(Info.M_JDEC,...
                                     Info.M_JRA,...
                                     CameraObj.Config.MountCameraDist,...
                                     CameraObj.Config.MountCameraPA,'degrees');
        else
            Info.RA  = Info.M_JDEC;
            Info.DEC = Info.M_JRA;
        end
        Info.RA = mod(Info.RA,360);
    else
        Info.RA  = Info.M_JDEC;
        Info.DEC = Info.M_JRA;
    end



    Info.AZ       = obs.classCommand(UnitObj.Mount,'Az');
    Info.ALT      = obs.classCommand(UnitObj.Mount,'Alt');
    Info.EQUINOX  = 2000.0;
    Info.AIRMASS  = celestial.coo.hardie(pi./2-Info.ALT./RAD);
    TRK=obs.classCommand(UnitObj.Mount,'TrackingSpeed');
    Info.TRK_RA   = TRK(1)/3600;  % [arcsec/s]
    Info.TRK_DEC  = TRK(2)/3600;  % [arcsec/s]

    % focuser information
    Info.FOCUS    = obs.classCommand(UnitObj.Focuser{itel},'Pos');
    Info.PRVFOCUS = obs.classCommand(UnitObj.Focuser{itel},'LastPos');



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
