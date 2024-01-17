function HeaderCell=constructHeader(UnitObj,itel)
    % Construct image header for takes of the nth telescope. Intended to
    %   work only both for local and remote telescopes as well as mount in this unit
    %
    % Input   : the telescope number 
    % Output  : - A 3 column cell array with header for image
    
    RAD = 180./pi;

    CameraObj  = UnitObj.Camera{itel};
    FocuserObj = UnitObj.Focuser{itel};
    MountObj = UnitObj.Mount;
    
    [CameraHeader, CameraInfo] = imageHeader(CameraObj);
    
    % get remaining info from mount and focuser 
    %  (The camera object is queried once more to get its eventual offset
    %  from RA and Dec, MountCameraDist. Moreover, JD is taken from the 
    %  already retrieved CameraInfo.JD)
    
    I = 0;
    
    % the following three are semi-fragile, since they assume that the
    %  keys are explicitly in the obs.UnitCS.NN.create.yml config file
    I = I + 1;
    Info(I).Key = 'PROJNAME';
    try
        ProjName=UnitObj.Config.ProjName;
    catch
        ProjName = 'LAST';
    end
    Info(I).Val = ProjName;
    
    I = I + 1;
    Info(I).Key = 'NODENUMB';
    try
        NodeNum = UnitObj.Config.NodeNumer;
    catch
        NodeNum = 1;
    end
    Info(I).Val = int32(NodeNum);

    I = I + 1;
    Info(I).Key = 'TIMEZONE';
    try
        TimeZone = UnitObj.Config.TimeZone;
    catch
        TimeZone = NaN;
    end
    Info(I).Val = TimeZone; % timezone can be fractional! (e.g. Nepal, New Zeland)
    
    if isa(MountObj,'obs.mount') || isa(MountObj,'obs.remoteClass')
        % Mount information
        MountNum = int16(sscanf(UnitObj.Id,'%d'));
        % OBSERVER
        %ORIGIN
        %OBSNAME
        %OBSPLACE

        I = I + 1;
        Info(I).Key = 'MOUNTNUM';
        Info(I).Val = MountNum;
        
        MountConfig  = MountObj.classCommand('Config');
        CameraConfig = CameraObj.classCommand('Config');
        
        I = I + 1;
        Info(I).Key = 'FULLPROJ';
        Info(I).Val = sprintf('%s.%02d.%02d.%02d',ProjName,NodeNum,MountNum,itel);

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
        Info(I).Val = Lat;
        
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
        M_RA = MountObj.classCommand('RA');
        Info(I).Val = M_RA;
        
        I = I + 1;
        Info(I).Key = 'M_DEC';
        M_Dec = MountObj.classCommand('Dec');
        Info(I).Val = M_Dec;
        
        I = I + 1;
        Info(I).Key = 'M_HA';
        Info(I).Val = convert.minusPi2Pi(LST - M_RA);
        
% OLD RA/Dec - mount J2000
%         J2000coord = MountObj.classCommand('j2000');
%         I = I + 1;
%         M_JRA = J2000coord(1);
%         Info(I).Key = 'M_JRA';
%         Info(I).Val = M_JRA;
%         
%         I = I + 1;
%         M_JDec = J2000coord(2);
%         Info(I).Key = 'M_JDEC';
%         Info(I).Val = M_JDec;
%         
%         I = I + 1;
%         Info(I).Key = 'M_JHA';
%         Info(I).Val = convert.minusPi2Pi(J2000coord(3));
        
        % RA & Dec including telescope offsets
        %   ? what about CameraConfig.TelescopeOffset' ?
        %     Besides, shouldn't this be moved to
        %     camera.imageHeader ?
        ConfigKeyName = 'TelescopeOffset'; %'MountCameraDist';
        if tools.struct.isfield_notempty(CameraConfig, ConfigKeyName)
            TelOffset = CameraConfig.(ConfigKeyName);
            if numel(TelOffset)<2
                TelOffset = [0 0];
            end
        else
            TelOffset = [0 0];
        end
        %ConfigKeyName = 'MountCameraPA';
        %if tools.struct.isfield_notempty(CameraConfig, ConfigKeyName)
        %    CamPA = CameraConfig.(ConfigKeyName);
        %else
        %    CamPA = 0;
        %end
	
        % buggy!
        % [RA, Dec] = celestial.coo.shift_coo(M_JRA, M_JDec, TelOffset(1), TelOffset(2), 'deg');
        % quick fix:
        %RA=M_JRA;
        %Dec=M_JDec;
        
        %[RA, Dec] = reckon(M_JRA, M_JDec, CamDist, CamPA, 'degrees');
                
%         I = I + 1;
%         Info(I).Key = 'RA';
%         Info(I).Val = RA;
%         
%         I = I + 1;
%         Info(I).Key = 'DEC';
%         Info(I).Val = Dec;
%         
%         I = I + 1;
%         HA = convert.minusPi2Pi(LST - RA);
%         Info(I).Key = 'HA';
%         Info(I).Val = convert.minusPi2Pi(HA);
                
        I = I + 1;
        Info(I).Key = 'EQUINOX';
        Info(I).Val = 2000.0;
        
        I = I + 1;
        Info(I).Key = 'M_AZ';
        Info(I).Val = MountObj.classCommand('Az');
        
        I = I + 1;
        Info(I).Key = 'M_ALT';
        Info(I).Val = MountObj.classCommand('Alt');
        
%  New J2000 considering nutation, aberration, refraction and pointing model

        % FFU -read MetData from site metereology and pass it to classCommand
        Aux = MountObj.classCommand(sprintf('pointingCorrection([],%.8f)',JD));
         
        % all the fields in Aux go into header, with this mapping:
        I = I + 1;
        Info(I).Key = 'M_JRA';
        Info(I).Val = Aux.RA_J2000;
        
        I = I + 1;
        Info(I).Key = 'M_JDEC';
        Info(I).Val = Aux.Dec_J2000;
        
        I = I + 1;
        Info(I).Key = 'M_ARA';
        Info(I).Val = Aux.RA_App;
        
        I = I + 1;
        Info(I).Key = 'M_AHA';
        Info(I).Val = Aux.HA_App;
        
        I = I + 1;
        Info(I).Key = 'M_ADEC';
        Info(I).Val = Aux.Dec_App;
        
        I = I + 1;
        Info(I).Key = 'M_ADRA';
        Info(I).Val = Aux.RA_AppDist;
        
        I = I + 1;
        Info(I).Key = 'M_ADHA';
        Info(I).Val = Aux.HA_AppDist;
        
        I = I + 1;
        Info(I).Key = 'M_ADDec';
        Info(I).Val = Aux.Dec_AppDist;
        
        I = I + 1;
        Info(I).Key = 'RA';
        Info(I).Val = Aux.RA_J2000 + TelOffset(1)/cosd(Aux.Dec_J2000);
        
        I = I + 1;
        Info(I).Key = 'DEC';
        Info(I).Val = Aux.Dec_J2000 + TelOffset(2);
        
        I = I + 1;
        Info(I).Key = 'M_AAZ'; % check intentions - just AZ, perhaps?
        Info(I).Val = Aux.Az_App;
        
        I = I + 1;
        Info(I).Key = 'M_AALT';  % check intentions - just ALT, perhaps?
        Info(I).Val = Aux.Alt_App;
        
        I = I + 1;
        Info(I).Key = 'AIRMASS';
        Info(I).Val = Aux.AirMass;
        
   % old computation of Az, Alt: no more relevant, I'd say.
%         [Az, Alt] = celestial.coo.hadec2azalt(HA, Dec, Lat, 'deg');
%         
%         I = I + 1;
%         Info(I).Key = 'AZ';
%         Info(I).Val = Az;
%         
%         I = I + 1;
%         Info(I).Key = 'ALT';
%         Info(I).Val = Alt;
%         
%         I = I + 1;
%         Info(I).Key = 'AIRMASS';
%         Info(I).Val = celestial.coo.hardie( (90 - Alt)./RAD);
                
        TrackingSpeed = MountObj.classCommand('TrackingSpeed');
        
        I = I + 1;
        Info(I).Key = 'TRK_RA';
        Info(I).Val = TrackingSpeed(1)./3600;  % [arcsec/s]
        
        I = I + 1;
        Info(I).Key = 'TRK_DEC';
        Info(I).Val = TrackingSpeed(2)./3600;  % [arcsec/s]
    end
    
    % mount temperature, reading 1wire sensors on the power switches
    I = I + 1;
    Info(I).Key = 'MNTTEMP';
    Info(I).Val = nanmean(UnitObj.classCommand('Temperature'));

    % focuser information
    if isa(FocuserObj,'obs.focuser') || isa(FocuserObj,'obs.remoteClass')
        I = I + 1;
        Info(I).Key = 'FOCUS';
        Info(I).Val = FocuserObj.classCommand('Pos');
        
        I = I + 1;
        Info(I).Key = 'PRVFOCUS';
        Info(I).Val = FocuserObj.classCommand('LastPos');
        
    end
    
    % Read additional fixed keys from Unit.Config.FITSHeader
    try
        if isfield(UnitObj.classCommand('Config'),'FITSHeader')
            ExtraKeys = UnitObj.classCommand('Config.FITSHeader');
            for i=1:numel(ExtraKeys)
                I= I + 1;
                Info(I).Key = ExtraKeys{i}{1};
                Info(I).Val  = ExtraKeys{i}{2};
            end
        end
    catch
    end
    
    % wrap it all up in HeaderCell
    N = numel(Info);
    HeaderCell = cell(N,3);
    HeaderCell(:,1) = {Info.Key};
    HeaderCell(:,2) = {Info.Val};
    
    HeaderCell = [CameraHeader; HeaderCell];


end
