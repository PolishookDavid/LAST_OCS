function HeaderCell=constructTelescopeHeader(UnitObj,itel)
    % Construct image header for takes of the nth telescope. Intended to
    %   work only both for local and remote telescopes as well as mount in this unit
    % In its typical use, though, this function is called automatically in
    %  the slaves only, when a new image is ready to be saved. The part
    %  with Unit and Mount information is supposed to have been already
    %  prewritten in Unit.UnitHeader in advance, typically when the
    %  exposure was started.
    %
    % Input   : the telescope number 
    % Output  : - A 3 column cell array with the header for the image
    
    RAD = 180./pi;

    CameraObj  = UnitObj.Camera{itel};
    FocuserObj = UnitObj.Focuser{itel};
    
    [CameraHeader,CameraInfo] = imageHeader(CameraObj);
    UnitHeader=UnitObj.UnitHeader;
    if ~isempty(UnitHeader)
        UnitHeaderKeys=UnitHeader(:,1);
    end
    
    CameraConfig = CameraObj.classCommand('Config');
    % get remaining info from mount and focuser 
    %  (The camera object is queried once more to get its eventual offset
    %  from RA and Dec, MountCameraDist. Moreover, JD is taken from the 
    %  already retrieved CameraInfo.JD)
    
    I = 0;

    % derive ProjName,NodeNum,MountNum from UnitObj.UnitHeader to
    % construct JD
    if ~isempty(UnitHeader)
        ProjName=UnitHeader{strcmp(UnitHeaderKeys,'PROJNAME'),2};
        NodeNum=UnitHeader{strcmp(UnitHeaderKeys,'NODENUMB'),2};
        MountNum=UnitHeader{strcmp(UnitHeaderKeys,'MOUNTNUM'),2};
        Lon=UnitHeader{strcmp(UnitHeaderKeys,'OBSLON'),2};
        Lat=UnitHeader{strcmp(UnitHeaderKeys,'OBSLAT'),2};
        I = I + 1;
        Info(I).Key = 'FULLPROJ';
        Info(I).Val = sprintf('%s.%02d.%02d.%02d',ProjName,NodeNum,MountNum,itel);
        Info(I).Descr = 'Full project identifier of the telescope';        
    else
        UnitObj.report('warning: empty Unit.UnitHeader!\n');
    end
    
    I = I + 1;
    Info(I).Key = 'LST';
    Ijd = find(strcmp({CameraInfo.Name},'JD'),1);
    JD  = CameraInfo(Ijd).Val;
    LST         = celestial.time.lst(JD, Lon./RAD,'a').*360;  % deg
    Info(I).Val = LST;
    Info(I).Descr = 'Local sidereal time at exposure start';
    
    I = I + 1;
    DateObs       = convert.time(JD,'JD','StrDate');
    Info(I).Key = 'DATE-OBS';
    Info(I).Val = DateObs{1};
    Info(I).Descr = 'Date of the observation';

    ConfigKeyName = 'TelescopeOffset'; %'MountCameraDist';
    if tools.struct.isfield_notempty(CameraConfig, ConfigKeyName)
        TelOffset = CameraConfig.(ConfigKeyName);
        if numel(TelOffset)<2
            TelOffset = [0 0];
        end
    else
        TelOffset = [0 0];
    end
    
    % update all mount physical and distortion-corrected mount coordinates,
    %  taking what was included in UnitHeader, and adding to it
    %  tracking_speed*Delta_t between command time and start exposure time
    if ~isempty(UnitHeader)
       JDStart=UnitHeader{strcmp(UnitHeaderKeys,'JD_START'),2};
       DeltaTsec=(JD-JDStart)*86400;
       TRK_RA=UnitHeader{strcmp(UnitHeaderKeys,'TRK_RA'),2}; % arcsec/sec
       TRK_DEC=UnitHeader{strcmp(UnitHeaderKeys,'TRK_DEC'),2};
       % Compute corrections. These are first order corrections, because
       %  we don't want to apply the pointing model. The problem is that
       %  logically pointingCorrection is a method of the physical class
       %  obs.mount. In the slave we have only a pointer to it as remote
       %  class, and we want to avoid the overhead and the headache of
       %  querying back the master.
       % All the relevant keys, which were already computed in UnitHeader
       % are updated here. Thus, as a fallback the uncorrected values will
       % at least be present.
       % The underlying assumption is that nothing went wrong in the
       % meantime, and the tracking speed remained constant.
       
       RAcorrection=(TRK_RA/3600-360/86164.0905)*DeltaTsec;
       HAcorrection=(TRK_RA/3600)*DeltaTsec;
       DECcorrection=(TRK_DEC/3600)*DeltaTsec; % in degrees
       
       J=find(strcmp(UnitHeaderKeys,'M_RA'));
       M_RA=UnitHeader{J,2};
       UnitHeader{J,2}= M_RA + RAcorrection;
       
       J=find(strcmp(UnitHeaderKeys,'M_HA'));
       UnitHeader{J,2}=UnitHeader{J,2} + HAcorrection;
       
       J=find(strcmp(UnitHeaderKeys,'M_DEC'));
       M_DEC=UnitHeader{J,2};
       UnitHeader{J,2}= M_DEC + DECcorrection;
       
       OutCoo=celestial.coo.horiz_coo([M_RA,M_DEC]/RAD, JD, [Lon,Lat]/RAD,'h');
       az=OutCoo(1)*RAD;
       alt=OutCoo(2)*RAD;
       UnitHeader{strcmp(UnitHeaderKeys,'M_AZ'),2} = az;
       UnitHeader{strcmp(UnitHeaderKeys,'M_ALT'),2} = alt;

       J=find(strcmp(UnitHeaderKeys,'M_JRA'));
       UnitHeader{J,2}=UnitHeader{J,2} + RAcorrection;

       J=find(strcmp(UnitHeaderKeys,'M_JDEC'));
       UnitHeader{J,2}=UnitHeader{J,2} + DECcorrection;

       J=find(strcmp(UnitHeaderKeys,'M_ARA'));
       M_ADRA=UnitHeader{J,2};
       UnitHeader{J,2} = M_ADRA + RAcorrection;

       J=find(strcmp(UnitHeaderKeys,'M_AHA'));
       UnitHeader{J,2}=UnitHeader{J,2} + HAcorrection;

       J=find(strcmp(UnitHeaderKeys,'M_ADEC'));
       M_ADEC=UnitHeader{J,2};
       UnitHeader{J,2} = M_ADEC + DECcorrection;

       J=find(strcmp(UnitHeaderKeys,'M_ADRA'));
       UnitHeader{J,2}=UnitHeader{J,2} + RAcorrection;

       J=find(strcmp(UnitHeaderKeys,'M_ADHA'));
       UnitHeader{J,2}=UnitHeader{J,2} + HAcorrection;

       J=find(strcmp(UnitHeaderKeys,'M_ADDEC'));
       UnitHeader{J,2}=UnitHeader{J,2} + DECcorrection;

       % check intentions - which coordinates are we using? Apparent,
       %  distorted... but of the mounts, not with telescope offsets
       OutCoo=celestial.coo.horiz_coo([M_ADRA,M_ADEC]/RAD,JD,[Lon,Lat]/RAD,'h');
       aaz=OutCoo(1)*RAD;
       aalt=OutCoo(2)*RAD;
       AirMass = celestial.coo.hardie((90-aalt)./RAD);
       UnitHeader{strcmp(UnitHeaderKeys,'M_AAZ'),2} = aaz;
       UnitHeader{strcmp(UnitHeaderKeys,'M_AALT'),2} = aalt;
       UnitHeader{strcmp(UnitHeaderKeys,'AIRMASS'),2} = AirMass;
       
       %  Dec_J2000 and RA_J2000 are included on purpose in UnitHeader
       Dec_J2000=UnitHeader{strcmp(UnitHeaderKeys,'M_JDEC'),2};
       RA_J2000=UnitHeader{strcmp(UnitHeaderKeys,'M_JRA'),2};
       if ~isempty(Dec_J2000)
           I = I + 1;
            Info(I).Key = 'RA';
            Info(I).Val = RA_J2000 + TelOffset(1)/cosd(Dec_J2000);
            Info(I).Descr = 'J2000 RA including telescope offset';
        end
        
        I = I + 1;
        Info(I).Key = 'DEC';
        Info(I).Val = Dec_J2000 + TelOffset(2);
        Info(I).Descr = 'J2000 Dec including telescope offset';
    end
    
    % focuser information
    if isa(FocuserObj,'obs.focuser') || isa(FocuserObj,'obs.remoteClass')
        I = I + 1;
        Info(I).Key = 'GITFOCUS';
        Info(I).Val = FocuserObj.classCommand('GitVersion');
        Info(I).Descr = 'git version of the focus driver';
        
        I = I + 1;
        Info(I).Key = 'FOCUS';
        Info(I).Val = FocuserObj.classCommand('Pos');
        Info(I).Descr = 'current focuser position';
        
        I = I + 1;
        Info(I).Key = 'PRVFOCUS';
        Info(I).Val = FocuserObj.classCommand('LastPos');        
        Info(I).Descr = 'previous focuser position';
    end
    
    % wrap it all up in HeaderCell
    N = numel(Info);
    HeaderCell = cell(N,3);
    HeaderCell(:,1) = {Info.Key};
    HeaderCell(:,2) = {Info.Val};
    HeaderCell(:,3) = {Info.Descr};
    
    HeaderCell = [UnitHeader; CameraHeader; HeaderCell];

end
