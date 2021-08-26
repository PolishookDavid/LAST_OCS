function [HeaderCell,AllInfo]=constructHeader(UnitObj,itel)
    % Construct image header for takes of the nth telescope. Intended to
    %   work only both for local and remote telescopes as well as mount in this unit
    % This could well be demoted to private method, it is temporarily left
    %  public for visibility
    %
    % Input   : the telescope number 
    % Output  : - A 3 column cell array with header for image
    %           - A structure with all the header key and vals.
    
    RAD = 180./pi;

    CameraObj=UnitObj.Camera{itel};
    FocuserObj=UnitObj.Focuser{itel};
    
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
    else
        % fill the header first with all which can be retrieved from the
        %  camera alone
        [CameraHeader,CameraInfo]=imageHeader(CameraObj);
    end
    
    % get remaining info from mount and focuser 
    %  (The camera object is queried once more to get its eventual offset
    %  from RA and Dec, MountCameraDist. Moreover, JD is taken from the 
    %  already retrieved CameraInfo.JD)
    if isa(UnitObj.Mount,'obs.mount') || isa(UnitObj.Mount,'obs.remoteClass')
        % Mount information
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
        Info.LST      = celestial.time.lst(CameraInfo.JD,Info.ObsLon./RAD,'a').*360;  % deg
        DateObs       = convert.time(CameraInfo.JD,'JD','StrDate');
        Info.DATE_OBS = DateObs{1};
        % get RA/Dec - Mount equinox of date
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
                [Info.DEC, Info.RA] = reckon(Info.M_JDEC, Info.M_JRA,...
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
    end

    % focuser information
    if isa(FocuserObj,'obs.focuser') || isa(FocuserObj,'obs.remoteClass')        
        Info.FOCUS    = FocuserObj.classCommand('Pos');
        Info.PRVFOCUS = FocuserObj.classCommand('LastPos');
    end
    
    % Now put the information from camera and rest of the unit together.
    % We use esplicitely CameraHeader, which can contain comments retrieved
    %  from Cameraobj.ConfigHeader, beyond the key-value pairs contained in
    %  CameraInfo
    AllInfo=CameraInfo(:);
    
    % Add Info fields to AllInfo, and Info -> HeaderCell for this part
    FN  = fieldnames(Info);
    Nfn = numel(FN);
    HeaderCell = cell(Nfn,3);
    for Ifn=1:Nfn
        AllInfo.(upper(FN{Ifn}))=Info.(FN{Ifn});
        HeaderCell{Ifn,1} = upper(FN{Ifn});
        HeaderCell{Ifn,2} = Info.(FN{Ifn});
    end
    
    HeaderCell = [CameraHeader(:)',HeaderCell(:)'];

end
