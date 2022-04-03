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

    CameraObj  = UnitObj.Camera{itel};
    FocuserObj = UnitObj.Focuser{itel};
    
    [CameraHeader, CameraInfo] = imageHeader(CameraObj);
    
    
    
%     % get image size
%     if isa(CameraObj,'obs.remoteClass')
%         SizeImIJ = CameraObj.Messenger.query(...
%             sprintf('size(%s.LastImage)',CameraObj.RemoteName));
%     else
%         SizeImIJ = size(CameraObj.LastImage);
%     end
% 
%     if prod(SizeImIJ)==0
%         UnitObj.reportError('no image taken by telescope %d, no header to create',...
%                             itel)
%         Info=struct();
%         HeaderCell=cell(0,3);
%         return
%     else
%         % fill the header first with all which can be retrieved from the
%         %  camera alone
%         [CameraHeader,CameraInfo] = imageHeader(CameraObj);
%     end
    
    % get remaining info from mount and focuser 
    %  (The camera object is queried once more to get its eventual offset
    %  from RA and Dec, MountCameraDist. Moreover, JD is taken from the 
    %  already retrieved CameraInfo.JD)
    
    I = 0;
    
    if isa(UnitObj.Mount,'obs.mount') || isa(UnitObj.Mount,'obs.remoteClass')
        % Mount information
        Info.MountNum = UnitObj.Mount.classCommand('Id');
        % OBSERVER
        %ORIGIN
        %OBSNAME
        %OBSPLACE
        
        MountConfig  = UnitObj.Mount.classCommand('Config');
        CameraConfig = CameraObj.classCommand('Config');
        
        I = I + 1;
        Info(I).Key = 'OBSLON';
        ConfigKeyName = 'ObsLon';
        if tools.struct.isfield_notempty(MountConfig, ConfigKeyName)
            Val = MountConfig.(ConfigKeyName);
        else
            Val = NaN;
        end
        Lon = Val;
        Info(I).Val = Val;
        
        I = I + 1;
        Info(I).Key = 'OBSLAT';
        ConfigKeyName = 'ObsLat';
        if tools.struct.isfield_notempty(MountConfig, ConfigKeyName)
            Val = MountConfig.(ConfigKeyName);
        else
            Val = NaN;
        end
        Lat = Val;
        Info(I).Val = Val;
        
        I = I + 1;
        Info(I).Key = 'OBSALT';
        ConfigKeyName = 'ObsHeight';
        if tools.struct.isfield_notempty(MountConfig, ConfigKeyName)
            Val = MountConfig.(ConfigKeyName);
        else
            Val = NaN;
        end
        Info(I).Val = Val;
        
        I = I + 1;
        Info(I).Key = 'LST';
        Ijd = find(strcmp({CameraInfo.Name},'JD'));
        JD  = CameraInfo(Ijd).Val;
        LST         = celestial.time.lst(JD, Lon./RAD,'a').*360;  % deg
        Info(I).Val = LST;
        
        
        I = I + 1;
        DateObs       = convert.time(JD,'JD','StrDate');
        Info(I).Key = 'DATE-OBS';
        Info(I).Val = DateObs{1};
        
        I = I + 1;
        Info(I).Key = 'M_RA';
        M_RA = UnitObj.Mount.classCommand('RA');
        Info(I).Val = M_RA;
        
        I = I + 1;
        Info(I).Key = 'M_DEC';
        Info(I).Val = UnitObj.Mount.classCommand('Dec');
        
        I = I + 1;
        Info(I).Key = 'M_HA';
        Info(I).Val = convert.minusPi2Pi(LST - M_RA);
        
        % RA/Dec - mount J2000
        J2000coord = UnitObj.Mount.classCommand('j2000');
        I = I + 1;
        M_JRA = J2000coord(1);
        Info(I).Key = 'M_JRA';
        Info(I).Val = M_JRA;
        
        I = I + 1;
        M_JDec = J2000coord(2);
        Info(I).Key = 'M_JDEC';
        Info(I).Val = M_JDec;
        
        I = I + 1;
        Info(I).Key = 'M_JHA';
        Info(I).Val = convert.minusPi2Pi(J2000coord(3));
        
        
        % RA & Dec including telescope offsets
        %   ? what about CameraConfig.TelescopeOffset' ?
        %     Besides, shouldn't this be moved to
        %     camera.imageHeader ?
	ConfigKeyName = 'TelescopeOffset'; %'MountCameraDist';
        if tools.struct.isfield_notempty(CameraConfig, ConfigKeyName)
	    TelOffset = CameraConfig.(ConfigKeyName);
            %CamDist = CameraConfig.(ConfigKeyName);
        else
	    TelOffset = [0 0];
            %CamDist = 0;
        end
        %ConfigKeyName = 'MountCameraPA';
        %if tools.struct.isfield_notempty(CameraConfig, ConfigKeyName)
        %    CamPA = CameraConfig.(ConfigKeyName);
        %else
        %    CamPA = 0;
        %end
	
        [RA, Dec] = celestial.coo.shift_coo(M_JRA, M_JDec, TelOffset(1), TelOffset(2), 'deg');
        %[RA, Dec] = reckon(M_JRA, M_JDec, CamDist, CamPA, 'degrees');
                
        I = I + 1;
        Info(I).Key = 'RA';
        Info(I).Val = RA;
        
        I = I + 1;
        Info(I).Key = 'DEC';
        Info(I).Val = Dec;
        
        I = I + 1;
        HA = convert.minusPi2Pi(LST - RA);
        Info(I).Key = 'HA';
        Info(I).Val = convert.minusPi2Pi(HA);
                
        I = I + 1;
        Info(I).Key = 'EQUINOX';
        Info(I).Val = 2000.0;
        
        I = I + 1;
        Info(I).Key = 'M_AZ';
        Info(I).Val = UnitObj.Mount.classCommand('Az');
        
        I = I + 1;
        Info(I).Key = 'M_ALT';
        Info(I).Val = UnitObj.Mount.classCommand('Alt');
        
        [Az, Alt] = celestial.coo.hadec2azalt(HA, Dec, Lat, 'deg');
        
        I = I + 1;
        Info(I).Key = 'AZ';
        Info(I).Val = Az;
        
        I = I + 1;
        Info(I).Key = 'ALT';
        Info(I).Val = Alt;
        
        I = I + 1;
        Info(I).Key = 'AIRMASS';
        Info(I).Val = celestial.coo.hardie( (90 - Alt)./RAD).*RAD;
                
        TrackingSpeed = UnitObj.Mount.classCommand('TrackingSpeed');
        
        I = I + 1;
        Info(I).Key = 'TRK_RA';
        Info(I).Val = TrackingSpeed(1)./3600;  % [arcsec/s]
        
        I = I + 1;
        Info(I).Key = 'TRK_DEC';
        Info(I).Val = TrackingSpeed(2)./3600;  % [arcsec/s]
    end
    
    % focuser information
    if isa(FocuserObj,'obs.focuser') || isa(FocuserObj,'obs.remoteClass')
        I = I + 1;
        Info(I).Key = 'FOCUS';
        Info(I).Val = FocuserObj.classCommand('Pos');
        
        I = I + 1;
        Info(I).Key = 'PRVFOCUS';
        Info(I).Val = FocuserObj.classCommand('LastPos');
        
    end
    
    N = numel(Info);
    HeaderCell = cell(N,3);
    HeaderCell(:,1) = {Info.Key};
    HeaderCell(:,2) = {Info.Val};
    
    HeaderCell = [CameraHeader; HeaderCell];

        
%         if tools.struct.isfield_notempty(UnitObj.Mount.classCommand('Config'),'ObsLat')
%             Info.ObsLat = UnitObj.Mount.classCommand('Config.ObsLat');
%         else
%             Info.ObsLat = NaN;
%         end
%         if tools.struct.isfield_notempty(UnitObj.Mount.classCommand('Config'),'ObsHeight')
%             Info.ObsAlt = UnitObj.Mount.classCommand('Config.ObsHeight');
%         else
%             Info.ObsAlt = NaN;
%         end
%         Info.LST      = celestial.time.lst(CameraInfo.JD,Info.ObsLon./RAD,'a').*360;  % deg
%         DateObs       = convert.time(CameraInfo.JD,'JD','StrDate');
%         Info.DATE_OBS = DateObs{1};
%         % get RA/Dec - Mount equinox of date
%         Info.M_RA     = UnitObj.Mount.classCommand('RA');
%         Info.M_DEC    = UnitObj.Mount.classCommand('Dec');
%         Info.M_HA     = convert.minusPi2Pi(Info.LST - Info.M_RA);
%         % RA/Dec - mount J2000
%         j2000coord=UnitObj.Mount.classCommand('j2000');
%         Info.M_JRA    = j2000coord(1);
%         Info.M_JDEC   = j2000coord(2);
%         Info.M_HA     = convert.minusPi2Pi(j2000coord(3));
%         % RA/Dec - J2000 camera center
%         if ~isempty(CameraObj.classCommand('Config'))
%             if tools.struct.isfield_notempty(CameraObj.classCommand('Config'),'MountCameraDist') && ...
%                     tools.struct.isfield_notempty(CameraObj.classCommand('Config'),'MountCameraPA')
%                 [Info.DEC, Info.RA] = reckon(Info.M_JDEC, Info.M_JRA,...
%                     CameraObj.classCommand('Config.MountCameraDist'),...
%                     CameraObj.classCommand('Config.MountCameraPA'),'degrees');
%             else
%                 Info.RA  = Info.M_JDEC;
%                 Info.DEC = Info.M_JRA;
%             end
%             Info.RA = mod(Info.RA,360);
%         else
%             Info.RA  = Info.M_JDEC;
%             Info.DEC = Info.M_JRA;
%         end    
%         Info.AZ       = UnitObj.Mount.classCommand('Az');
%         Info.ALT      = UnitObj.Mount.classCommand('Alt');
%         Info.EQUINOX  = 2000.0;
%         Info.AIRMASS  = celestial.coo.hardie(pi./2-Info.ALT./RAD);
%         TRK=UnitObj.Mount.classCommand('TrackingSpeed');
%         Info.TRK_RA   = TRK(1)/3600;  % [arcsec/s]
%         Info.TRK_DEC  = TRK(2)/3600;  % [arcsec/s]
%     end
% 
%     % focuser information
%     if isa(FocuserObj,'obs.focuser') || isa(FocuserObj,'obs.remoteClass')        
%         Info.FOCUS    = FocuserObj.classCommand('Pos');
%         Info.PRVFOCUS = FocuserObj.classCommand('LastPos');
%     end
%     
    % Now put the information from camera and rest of the unit together.
    % We use esplicitely CameraHeader, which can contain comments retrieved
    %  from Cameraobj.ConfigHeader, beyond the key-value pairs contained in
    %  CameraInfo
%     AllInfo=CameraInfo(:);
%     
%     % Add Info fields to AllInfo, and Info -> HeaderCell for this part
%     FN  = fieldnames(Info);
%     Nfn = numel(FN);
%     HeaderCell = cell(Nfn,3);
%     for Ifn=1:Nfn
%         AllInfo.(upper(FN{Ifn}))=Info.(FN{Ifn});
%         HeaderCell{Ifn,1} = upper(FN{Ifn});
%         HeaderCell{Ifn,2} = Info.(FN{Ifn});
%     end
%     
%     HeaderCell = [CameraHeader; HeaderCell];

end
