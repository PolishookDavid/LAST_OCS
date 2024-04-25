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
    
    [CameraHeader, CameraInfo] = imageHeader(CameraObj);
    
    % get remaining info from mount and focuser 
    %  (The camera object is queried once more to get its eventual offset
    %  from RA and Dec, MountCameraDist. Moreover, JD is taken from the 
    %  already retrieved CameraInfo.JD)
    
    I = 0;

    % TODO! derive ProjName,NodeNum,MountNum from UnitObj.UnitHeader to
    % construct JD
%         I = I + 1;
%         Info(I).Key = 'FULLPROJ';
%         Info(I).Val = sprintf('%s.%02d.%02d.%02d',ProjName,NodeNum,MountNum,itel);
%         Info(I).Descr = '';

        % TODO Lat, Lon from UnitObj.UnitHeader
%         I = I + 1;
%         Info(I).Key = 'LST';
%         Ijd = find(strcmp({CameraInfo.Name},'JD'));
%         JD  = CameraInfo(Ijd).Val;
%         LST         = celestial.time.lst(JD, Lon./RAD,'a').*360;  % deg
%         Info(I).Val = LST;
%         Info(I).Descr = '';
%         
%         
%         I = I + 1;
%         DateObs       = convert.time(JD,'JD','StrDate');
%         Info(I).Key = 'DATE-OBS';
%         Info(I).Val = DateObs{1};
%         Info(I).Descr = '';
%

% TODO M_RA from UnitHeader
%         I = I + 1;
%         Info(I).Key = 'M_HA';
%         Info(I).Val = convert.minusPi2Pi(LST - M_RA);
%         Info(I).Descr = '';
        
    
    ConfigKeyName = 'TelescopeOffset'; %'MountCameraDist';
    if tools.struct.isfield_notempty(CameraConfig, ConfigKeyName)
        TelOffset = CameraConfig.(ConfigKeyName);
        if numel(TelOffset)<2
            TelOffset = [0 0];
        end
    else
        TelOffset = [0 0];
    end
    if ~isempty(Aux.Dec_J2000) % derive this from UnitHeader!
        I = I + 1;
        Info(I).Key = 'RA';
        Info(I).Val = Aux.RA_J2000 + TelOffset(1)/cosd(Aux.Dec_J2000);
        Info(I).Descr = '';
    end
    
    I = I + 1;
    Info(I).Key = 'DEC';
    Info(I).Val = Aux.Dec_J2000 + TelOffset(2); % derive this from UnitHeader!
    Info(I).Descr = '';

    
    % focuser information
    if isa(FocuserObj,'obs.focuser') || isa(FocuserObj,'obs.remoteClass')
        I = I + 1;
        Info(I).Key = 'FOCUS';
        Info(I).Val = FocuserObj.classCommand('Pos');
        Info(I).Descr = '';
        
        I = I + 1;
        Info(I).Key = 'PRVFOCUS';
        Info(I).Val = FocuserObj.classCommand('LastPos');        
        Info(I).Descr = '';
    end
    
    % wrap it all up in HeaderCell
    N = numel(Info);
    HeaderCell = cell(N,3);
    HeaderCell(:,1) = {Info.Key};
    HeaderCell(:,2) = {Info.Val};
    HeaderCell(:,3) = {Info.Descr};
    
    HeaderCell = [UnitObj.UnitHeader; CameraHeader; HeaderCell];


end
