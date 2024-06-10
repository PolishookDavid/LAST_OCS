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
        % Lat=UnitHeader{strcmp(UnitHeaderKeys,'OBSLAT'),2};
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
    Info(I).Descr = 'Local sidereal time';
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
    
    %  Dec_J2000 and RA_J2000 are included on purpose in UnitHeader
    if ~isempty(UnitHeader)
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
    
    HeaderCell = [UnitObj.UnitHeader; CameraHeader; HeaderCell];

end
