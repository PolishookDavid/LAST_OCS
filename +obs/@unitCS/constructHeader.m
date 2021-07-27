function [HeaderCell,Info]=constructHeader(UnitObj,itel)
    % Construct image header for takes of the nth telescope. Intended to
    %   work only both for local and remote telescopes as well as mount in this unit
    % Input   : the telescope number 
    % Output  : - A 3 column cell array with header for image
    %           - A structure with all the header key and vals.

    CameraObj=UnitObj.Camera{itel};
    
    if isa(CameraObj,'obs.remoteClass')
        SizeImIJ = CameraObj.Messenger.query(...
            sprintf('size(%s.LastImage)',CameraObj.RemoteName));
    else
        SizeImIJ = size(CameraObj.LastImage);
    end

    if prod(SizeImIJ)==0
        UnitObj.reportError(sprintf('no image taken by telescope %d, no header to create',...
                            itel))
        Info=struct();
        HeaderCell=cell(0,3);
        return
    end
    
    RAD = 180./pi;

    % Image related information
    %    12345678
    Info.NAXIS    = numel(SizeImIJ);
    Info.NAXIS1   = SizeImIJ(2);
    Info.NAXIS2   = SizeImIJ(1);
    Info.BITPIX   = -32;
    Info.BZERO    = 0.0;
    Info.BSCALE   = 1.0;
    Info.IMTYPE   = CameraObj.classCommand('ImType');
    Info.OBJECT   = CameraObj.classCommand('Object');

    % internal gain
    Info.INTGAIN  = CameraObj.classCommand('Gain');

    % keys which may be or be not in Config:
    % Gain, Read noise, Dark current
    Keys={'GAIN','DARKCUR','READNOI'};
    for i=1:numel(Keys)
        Field = Keys{i};
        if isfield(CameraObj.classCommand('Config'),Field)
            Info.(Field)     = CameraObj.classCommand('Config').(Field);
        else
            Info.(Field)     = NaN;
        end
    end
    %
    Info.BINX     = CameraObj.classCommand('Binning(1)');
    Info.BINY     = CameraObj.classCommand('Binning(2)');
    % 
    Info.CamNum   = CameraObj.classCommand('CameraNumber');
    Info.CamPos   = CameraObj.classCommand('CameraPos');
    Info.CamType  = class(CameraObj);
    Info.CamModel = CameraObj.classCommand('CameraModel');
    Info.CamName  = CameraObj.classCommand('CameraName');
    % Mount informtaion
    Info.MountNum = UnitObj.Mount.classCommand('Id');

    % OBSERVER
    %ORIGIN
    %OBSNAME
    %OBSPLACE


    if tools.struct.isfield_notempty(UnitObj.Mount.classCommand('Config'),'ObsLon')
        Info.ObsLon = UnitObj.Mount.classCommand('Config.ObsLon');
    else
        Info.ObsLon = NaN;
    end
    if tools.struct.isfield_notempty(UnitObj.Mount.classCommand('Config'),'ObsLat')
        Info.ObsLat = UnitObj.Mount.classCommand('Config.ObsLat');
    else
        Info.ObsLat = NaN;
    end
    if tools.struct.isfield_notempty(UnitObj.Mount.classCommand('Config'),'ObsHeight')
        Info.ObsHeight = UnitObj.Mount.classCommand('Config.ObsHeight');
    else
        Info.ObsHeight = NaN;
    end

    %Info.JD       = juliandate(CameraObj.classCommand('LastImageTime'));
    Info.JD       = 1721058.5 + CameraObj.classCommand('TimeStartLastImage');
    %Info.ExpTime  = CameraObj.classCommand('LastImageExpTime');
    Info.ExpTime  = CameraObj.classCommand('ExpTime');
    Info.LST      = celestial.time.lst(Info.JD,Info.ObsLon./RAD,'a').*360;  % deg
    DateObs       = convert.time(Info.JD,'JD','StrDate');
    Info.DATE_OBS = DateObs{1};

    

    % get RA/Dec - Mount equinox of date
    % This was conceived to query eventually a remote mount from a slave
    % unit. Rethink
    Info.M_RA     = UnitObj.Mount.classCommand('RA');

    Info.M_DEC    = UnitObj.Mount.classCommand('Dec');
    Info.M_HA     = convert.minusPi2Pi(Info.LST - Info.M_RA);
    % RA/Dec - mount J2000
    j2000coord=UnitObj.Mount.classCommand('j2000');
    Info.M_JRA    = j2000coord(1);
    Info.M_JDEC   = j2000coord(2);
    Info.M_HA     = convert.minusPi2Pi(j2000coord(3));
    % RA/Dec - J2000 camera center
    if ~isempty(CameraObj.classCommand('Config'))
        if tools.struct.isfield_notempty(CameraObj.classCommand('Config'),'MountCameraDist') && ...
                tools.struct.isfield_notempty(CameraObj.classCommand('Config'),'MountCameraPA')
            [Info.DEC, Info.RA] = reckon(Info.M_JDEC,...
                                     Info.M_JRA,...
                                     CameraObj.classCommand('Config.MountCameraDist'),...
                                     CameraObj.classCommand('Config.MountCameraPA'),'degrees');
        else
            Info.RA  = Info.M_JDEC;
            Info.DEC = Info.M_JRA;
        end
        Info.RA = mod(Info.RA,360);
    else
        Info.RA  = Info.M_JDEC;
        Info.DEC = Info.M_JRA;
    end



    Info.AZ       = UnitObj.Mount.classCommand('Az');
    Info.ALT      = UnitObj.Mount.classCommand('Alt');
    Info.EQUINOX  = 2000.0;
    Info.AIRMASS  = celestial.coo.hardie(pi./2-Info.ALT./RAD);
    TRK=UnitObj.Mount.classCommand('TrackingSpeed');
    Info.TRK_RA   = TRK(1)/3600;  % [arcsec/s]
    Info.TRK_DEC  = TRK(2)/3600;  % [arcsec/s]

    % focuser information
    Info.FOCUS    = UnitObj.Focuser{itel}.classCommand('Pos');
    Info.PRVFOCUS = UnitObj.Focuser{itel}.classCommand('LastPos');



    % struct to HeaderCell + comments
    % Input : Info, CommentsDB
    CommentsDB = CameraObj.classCommand('ConfigHeader');

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
