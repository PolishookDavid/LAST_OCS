function HeaderCell=constructUnitHeader(UnitObj)
    % Construct the part of the FITS image header which is derived from
    %  elements known to the unitCS object and to the Mount object. It is
    %  more efficient to construct this in the master unit and to dispatch
    %  the result to the various slaves, rather than having each slave
    %  query the master multiple times.
    %
    % Typically, this function is called by UnitObj.takeExposure, and the
    %  header reflects values read prior to the exposure. Temperatures
    %  won't change significantly, but the mount might fault during the
    %  exposure, and that won't be reflected in the FITS header
    %
    % Output  : - A 3 column cell array with header for image
    % Additionally, the result is stored in UnitObj.UnitHeader.
    
    RAD = 180./pi;

    MountObj = UnitObj.Mount;
    
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
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Key = 'NODENUMB';
    try
        NodeNum = UnitObj.Config.NodeNumer;
    catch
        NodeNum = 1;
    end
    Info(I).Val = int32(NodeNum);
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Key = 'TIMEZONE';
    try
        TimeZone = UnitObj.Config.TimeZone;
    catch
        TimeZone = NaN;
    end
    Info(I).Val = TimeZone; % timezone can be fractional! (e.g. Nepal, New Zeland)
    Info(I).Descr = '';
    
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
        Info(I).Descr = 'mount number';
        
        MountConfig  = MountObj.classCommand('Config');
        
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
        Info(I).Descr = 'longitude of the observatory';
        
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
        Info(I).Descr = 'latitude of the observatory';
        
        I = I + 1;
        Info(I).Key = 'OBSALT';
        ConfigKeyName = 'ObsHeight';
        if tools.struct.isfield_notempty(MountConfig, ConfigKeyName)
            Val = MountConfig.(ConfigKeyName);
        else
            Val = NaN;
        end
        Info(I).Val = Val;
        Info(I).Descr = 'height of the observatory';
        
        I = I + 1;
        Info(I).Key = 'GITASTRP';
        Info(I).Val = UnitObj.classCommand('AstroPackGitVersion');
        Info(I).Descr = 'git version of AstroPack';
        
        I = I + 1;
        Info(I).Key = 'GIT_UNIT';
        Info(I).Val = UnitObj.classCommand('GitVersion');
        Info(I).Descr = 'git version of the unitCS software';
        
        if ~isempty(UnitObj.Slave) && isa(UnitObj.Slave(1),'obs.util.SpawnedMatlab')
            I = I + 1;
            Info(I).Key = 'GIT_MESS';
            Info(I).Val = UnitObj.Slave(1).GitVersion;
            Info(I).Descr = 'git version of intercommunication software';
        end
        
        I = I + 1;
        Info(I).Key = 'GITSWITC';
        Info(I).Val = UnitObj.PowerSwitch{1}.classCommand('GitVersion');
        Info(I).Descr = 'git version of the power switch software';
        

        I = I + 1;
        Info(I).Key = 'GITMOUNT';
        Info(I).Val = MountObj.classCommand('GitVersion');
        Info(I).Descr = 'git version of the mount driver software';
        
        
        I = I + 1;
        Info(I).Key = 'M_RA';
        M_RA = MountObj.classCommand('RA');
        Info(I).Val = M_RA;
        Info(I).Descr = 'mount physical pointing right ascension';
        
        I = I + 1;
        Info(I).Key = 'M_HA';
        Info(I).Val = convert.minusPi2Pi(MountObj.LST - M_RA);
        Info(I).Descr = 'Phisical HA pointed at by the mount';

        I = I + 1;
        Info(I).Key = 'M_DEC';
        M_Dec = MountObj.classCommand('Dec');
        Info(I).Val = M_Dec;
        Info(I).Descr = 'mount physical pointing declination';
                
        I = I + 1;
        Info(I).Key = 'EQUINOX';
        Info(I).Val = 2000.0;
        Info(I).Descr = '';
        
        I = I + 1;
        Info(I).Key = 'M_AZ';
        Info(I).Val = MountObj.classCommand('Az');
        Info(I).Descr = 'mount physical pointing azimuth';
        
        I = I + 1;
        Info(I).Key = 'M_ALT';
        Info(I).Val = MountObj.classCommand('Alt');
        Info(I).Descr = 'mount physical pointing altitude';
        
%  New J2000 considering nutation, aberration, refraction and pointing model
%   There is a dependence on time here. Ideally, one would insert here the
%   time at which the exposures are sarted, or ended, or the mean of the
%   two. These exact times though are known only post facto in the slaves.
%   In the previous implemenatation, all the mount data was queried by each
%   slave at the time of saving the images, which caused an overhead of
%   several seconds. To avoid it, in first approximation we use here JD at
%   the time the this function is called. The assumptions are that: 1)
%   astronomic motion corrections to the pointing are negligible on the
%   scale of seconds, b) whenever we are tracking at sidereal rate, and
%   the mount behaves normally, RA remains almost constant.

        JD = celestial.time.julday();
        Aux = MountObj.classCommand(sprintf('pointingCorrection([],%.8f)',JD));
         
        % all the fields in Aux go into header, with this mapping:
        I = I + 1;
        Info(I).Key = 'M_JRA';
        Info(I).Val = Aux.RA_J2000;
        Info(I).Descr = 'mount J2000 RA';

        % pointing coordinates M_JDEC and M_JRA of the center wouldn't be
        %  needed by themselves, but we need them to be in UnitHeader, so
        %  that the slaves can sum to them the telescope offsets
        I = I + 1;
        Info(I).Key = 'M_JDEC';
        Info(I).Val = Aux.Dec_J2000;
        Info(I).Descr = 'mount J2000 Dec';
        
        I = I + 1;
        Info(I).Key = 'M_ARA';
        Info(I).Val = Aux.RA_App;
        Info(I).Descr = 'mount apparent equinox of date RA';
        
        I = I + 1;
        Info(I).Key = 'M_AHA';
        Info(I).Val = Aux.HA_App;
        Info(I).Descr = 'mount apparent equinox of date HA';
        
        I = I + 1;
        Info(I).Key = 'M_ADEC';
        Info(I).Val = Aux.Dec_App;
        Info(I).Descr = 'mount apparent equinox of date Dec';
        
        I = I + 1;
        Info(I).Key = 'M_ADRA';
        Info(I).Val = Aux.RA_AppDist;
        Info(I).Descr = 'mount apparent RA with distortion';
        
        I = I + 1;
        Info(I).Key = 'M_ADHA';
        Info(I).Val = Aux.HA_AppDist;
        Info(I).Descr = 'mount apparent HA with distortion';
        
        I = I + 1;
        Info(I).Key = 'M_ADDec';
        Info(I).Val = Aux.Dec_AppDist;
        Info(I).Descr = 'mount apparent Dec with distortion';
        
        I = I + 1;
        Info(I).Key = 'RA_J2000';
        Info(I).Val = Aux.RA_J2000;
        Info(I).Descr = 'RA of the mount center';
        
        I = I + 1;
        Info(I).Key = 'DECJ2000';
        Info(I).Val = Aux.Dec_J2000;
        Info(I).Descr = 'Dec of the mount center';
        
        I = I + 1;
        Info(I).Key = 'M_AAZ'; % check intentions - just AZ, perhaps?
        Info(I).Val = Aux.Az_App;
        Info(I).Descr = 'mount apparent azimuth';
        
        I = I + 1;
        Info(I).Key = 'M_AALT';  % check intentions - just ALT, perhaps?
        Info(I).Val = Aux.Alt_App;
        Info(I).Descr = 'mount apparent altitude';
        
        I = I + 1;
        Info(I).Key = 'AIRMASS';
        Info(I).Val = Aux.AirMass;
        Info(I).Descr = '';
                
        TrackingSpeed = MountObj.classCommand('TrackingSpeed');
        
        I = I + 1;
        Info(I).Key = 'TRK_RA';
        Info(I).Val = TrackingSpeed(1).*3600;  % [arcsec/s]
        Info(I).Descr = 'Tracking speed on RA';
        
        I = I + 1;
        Info(I).Key = 'TRK_DEC';
        Info(I).Val = TrackingSpeed(2).*3600;  % [arcsec/s]
        Info(I).Descr = 'Tracking speed on Dec';
    end
    
    % mount temperature, reading 1wire sensors on the power switches
    I = I + 1;
    Info(I).Key = 'MNTTEMP';
    Info(I).Val = nanmean(UnitObj.classCommand('Temperature'));
    Info(I).Descr = 'Temperature at the mount sensors';

    
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
    
    % FFU -read MetData from site meteorology and pass it to classCommand

    % wrap it all up in HeaderCell
    N = numel(Info);
    HeaderCell = cell(N,3);
    HeaderCell(:,1) = {Info.Key};
    HeaderCell(:,2) = {Info.Val};
    HeaderCell(:,3) = {Info.Descr};
    
    UnitObj.UnitHeader= HeaderCell;

end
