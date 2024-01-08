function [Flag,OutRA,OutDec,Aux]=goToTarget2(MountObj, RA, Dec, Shift, ApplyDist)
    % goToTarget given its J2000.0 coordinates or name
    % Input  : - J2000.0 R.A., [deg|sex] or object name.
    %            If second input is provided and RA is not numeric, then
    %            will assume input is in sexagesinal coordinates.
    %          - J2000.0 Dec. [deg|sex]. If empty, then will interpret the
    %            first input argument as an object name.
    %            Default is [].
    %          - Additional [RA Dec] shift to add to coordinates [deg].
    %            This is useful in order to set the position to one of the
    %            cameras.
    %            If a char array ('1'|'2'|'3'|'4') then will shift the
    %            position to the center of the requested camera.
    %            If [] use default.
    %            Default is [0 0].
    %          - A logical indicating if to apply the distortion
    %            corrections. Default is true.
    %
    % Output : - A logical flag indicatirng if sucessful.
    %          See code for additional output arguments.
    % Author : Eran Ofek (Jan 2024)
    % Example: M.goToTarget2(150, +20, '1')
    %          M.goToTarget('12:00:10.0','-10:10:10.0');
    %          M.goToTarget('M31');
    %          M.goToTarget('M15',[],[1 1]);
    %          M.goToTarget('M81',[],[0 0 ], false);

   

    if nargin<5
        ApplyDist = true;
        if nargin<4
            Shift = [0 0];
            if nargin<3
                Dec = [];
            else
                error('Not enough input arguments');
            end
        end
    end

    if isempty(Shift)
        Shift = [0 0];
    end

    RAD = 180./pi;
    MinAlt = 10;
    HALimit = 120;
    
    % Get current UTC time
    % Note that computer clock must be set to UTC
    % FFU: add test that computer clock is in UTC
    JD = celestial.time.julday;    

    % initilaize output to default values
    OutRA   = NaN;
    OutDec  = NaN;
    Aux.RA_J2000    = NaN;
    Aux.Dec_J2000   = NaN;
    Aux.RA_App      = NaN;
    Aux.HA_App      = NaN;
    Aux.Dec_App     = NaN;
    Aux.RA_AppDist  = NaN;
    Aux.HA_AppDist  = NaN;
    Aux.Dec_AppDist = NaN;

    % FFU: read from congiguration
    if ischar(Shift)
        switch Shift
            case '1'
                Shift = -[+1.65 +1.1];
            case '2'
                Shift = -[+1.65 -1.1];
            case '3'
                Shift = -[-1.65 -1.1];
            case '4'
                Shift = -[-1.65 +1.1];
            otherwise
                error('Unknwon Shift option');
        end
    end


    if max(abs(Shift))>2
        Flag = false;
        error('Shift of more than 2 deg is not allowed');
    else
        
        switch lower(MountObj.Status)
            case 'park'
                MountObj.LogFile.write('Error: Attempt to slew telescope while parking');
                Flag = false;
                %error('Can not slew telescope while parking');
            otherwise
                % Convert input into RA/Dec [input deg, output deg]
                GeoPos = [MountObj.ObsLon./RAD, MountObj.ObsLat./RAD, MountObj.ObsHeight];   % [rad rad m]
    
    
                % treat Shift
    
    
                % FFU: considering reading meterorological data...
                MetData.Wave = 5000; % A
                MetData.Temp = 15;   % C
                MetData.P    = 760;  % Hg
                MetData.Pw   = 8;    % Hg
                [OutRA, OutDec, Alt, Refraction, Aux] = celestial.convert.j2000_toApparent(RA, Dec, JD,...
                                                                   'InUnits','deg',...
                                                                   'Epoch',2000,...
                                                                   'OutUnits','deg',...
                                                                   'OutEquinox',[],...
                                                                   'OutEquinoxUnits','JD',...
                                                                   'OutMean',false,...
                                                                   'PM_RA',0,...
                                                                   'PM_Dec',0,...
                                                                   'Plx',1e-2,...
                                                                   'RV',0,...
                                                                   'INPOP',MountObj.INPOP,...
                                                                   'GeoPos',GeoPos,...
                                                                   'TypeLST','m',...
                                                                   'ApplyAberration',true,...
                                                                   'ApplyRefraction',true,...
                                                                   'Wave',MetData.Wave,...
                                                                   'Temp',MetData.Temp,...
                                                                   'Pressure',MetData.P,...
                                                                   'Pw',MetData.Pw,...
                                                                   'ShiftRA',Shift(1),...
                                                                   'ShiftDec',Shift(2),...
                                                                   'ApplyDistortion',ApplyDist,...
                                                                   'InterpHA',MountObj.PointingModel.InterpHA,...
                                                                   'InterpDec',MountObj.PointingModel.InterpDec);

            
                % verification:
                if Alt<MinAlt
                    fprintf('Error: Target requested altitude (%f) is below limit (%f)',Alt,MinAlt)
                    MountObj.LogFile.write(sprintf('Error: Target requested altitude (%f) is below limit (%f)',Alt,MinAlt));
                    Flag = false;
                end
                
                if abs(Aux.HA_App)>MountObj.HALimit
                    fprintf('Error: Requested HA (%f) is out of allowd range',Aux.HA_App)
                    MountObj.LogFile.write(sprintf('Error: Requested HA (%f) is out of allowd range',Aux.HA_App));
                    Flag = false;
                end

                % move mount
                % MountObj.goTo(OutRA, OutDec, 'eq');

        end
        
    end

    % write coordinates to MountObj
    % MountObj.RA_J2000   = Aux.RA_J2000;     % M_JRA
    % MountObj.Dec_J2000  = Aux.Dec_J2000;    % M_JDEC
    % MountObj.RA_App     = Aux.RA_App;       % M_ARA
    % MountObj.HA_App     = Aux.HA_App;       % M_AHA
    % MountObj.Dec_App    = Aux.Dec_App;      % M_ADEC
    % MountObj.RA_AppDist = Aux.RA_AppDist;   % M_ADRA
    % MountObj.HA_AppDist = Aux.HA_AppDist;   % M_ADHA
    % MountObj.Dec_AppDist= Aux.Dec_AppDist;  % M_ADDEC
    %                                         % RA = M_JRA + CamShiftRA./cosd(M_JDEC)
    %                                         % DEC = M_JDEC + CameraShiftDec 

end