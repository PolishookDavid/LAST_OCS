function [Flag,RA,Dec,Aux]=goToTarget(MountObj, Long, Lat, varargin)
    % Send mount to coordinates/name and start tracking
    % Package: @mount
    % Description: Send mount to a given coordinates in some coordinate system
    %              or equinox, or an object name; convert it to euatorial coordinates
    %              that includes the atmospheric refraction correction and optional
    %              telescope distortion model (T-point model).
    % Input  : - Longitude in some coordinate system, or object name.
    %            Longitude can be either sexagesimal coordinates or numeric
    %            calue in degress (or radians if InputUnits='rad').
    %            Object name is converted to coordinates using either SIMBAD,
    %            NED or JPL horizons.
    %          - Like the first input argument, but for the latitude.
    %            If empty, or not provided, than the first argument is assumed
    %            to be an object name.
    %          * Arbitrary number of pairs of arguments: ...,keyword,value,...
    %            where keyword are one of the followings:
    %            'InCooType'  - Input coordinates frame:
    %                           'a' - Az. Alt.
    %                           'g' - Galactic.
    %                           'e' - Ecliptic
    %                           - A string start with J (e.g., 'J2000.0').
    %                           Equatorial coordinates with mean equinox of
    %                           date, where the year is in Julian years.
    %                           -  A string start with t (e.g., 't2020.5').
    %                           Equatorial coordinates with true equinox of
    %                           date.
    %                           Default is 'J2000.0'
    %             
    %            'NameServer' - ['simbad'] | 'ned' | 'jpl'.
    %            'DistFun'    - Distortion function handle.
    %                           The function is of the form:
    %                           [DistHA,DistDec]=@Fun(HA,Dec), where all the
    %                           input and output are in degrees.
    %                           Default is empty. If not given return [0,0].
    %            'InputUnits' - Default is 'deg'.
    %            'OutputUnits'- Default is 'deg'
    %            'Temp'       - Default is 15 C.
    %            'Wave'       - Default is 5500 Ang.
    %            'PressureHg' - Default is 760 mm Hg.
    % Output : - Flag 0 if illegal input coordinates, 1 if ok.
    %          - Apparent R.A.
    %          - Apparent Dec.
    %          - A structure containing the intermidiate values.
    % License: GNU general public license version 3
    %     By : Eran Ofek                    Feb 2020
    % Example: [DistRA,DistDec,Aux]=mount.goToTarget(10,50)
    %          mount.goToTarget(10,50,'InCooType','a')
    %          mount.goToTarget('10:00:00','+50:00:00');
    %          mount.goToTarget('M31');
    %          mount.goToTarget('9804;',[],'NameServer','jpl')
    %--------------------------------------------------------------------------

    RAD = 180./pi;

    if nargin<3
        Lat = [];
    end
    
    
%     FFU
%     InCam = [];
%     if ~isempty(InCam)
%         % set coordinate such that center will be in camera #
%         
%     end
%     
%     
    JD = celestial.time.julday;

    Flag = false;

    switch lower(MountObj.Status)
        case 'park'
            
            MountObj.LogFile.write('Error: Attempt to slew telescope while parking');
            error('Can not slew telescope while parking');
        otherwise
            % Convert input into RA/Dec [input deg, output deg]
            try
                OutputCooType=MountObj.CoordType;
                if strcmp(OutputCooType,'tdate')
                    % why not 'tdate' altogether?
                    OutputCooType = sprintf('J%8.3f',convert.time(JD,'JD','J'));
                end
            catch
                warning('mount coordinate system not known - assuming Equinox of date');
                OutputCooType = sprintf('J%8.3f',convert.time(JD,'JD','J'));
            end
            
            [RA, Dec, Aux] = celestial.coo.convert2equatorial(Long, Lat, varargin{:},'OutCooType',OutputCooType,...
                                                              'DistFunHA',MountObj.PointingModel.InterpHA,...
                                                              'DistFunDec',MountObj.PointingModel.InterpDec,...
                                                              'DistIsDelta',true);
            
            
            
            if isnan(RA) || isnan(Dec)
                MountObj.LogFile.write('Error: RA or Dec are NaN');
                error('RA or Dec are NaN');
            end
            
            % validate coordinates
            % note that input is in [rad]
            
            if isnan(MountObj.ObsLon) || isnan(MountObj.ObsLat)
                % attempting to move mount when ObsLon/ObsLat
                % are unknown
                MountObj.LogFile.write('Attempting to move mount when ObsLon/ObsLat are unknown');
                error('Attempting to move mount when ObsLon/ObsLat are unknown');
            end
            
            [Flag,FlagRes] = celestial.coo.is_coordinate_ok(RA./RAD, Dec./RAD, JD, ...
                'Lon', MountObj.ObsLon./RAD, ...
                'Lat', MountObj.ObsLat./RAD, ...
                'AltMinConst', MountObj.MinAlt./RAD,...
                'AzAltConst', MountObj.AzAltLimit./RAD);
            
            
            if Flag
                
                % Start slewing
                MountObj.goTo(RA, Dec, 'eq');
                
            else
                % coordinates are not ok
                MountObj.LogFile.write('Coordinates are not valid - not slewing to requested target');
                
                if ~FlagRes.Alt
                    MountObj.LastError = 'Target Alt too low';
                    MountObj.LogFile.write('Target Alt too low');
                end
                if ~FlagRes.AzAlt
                    MountObj.LastError = 'Target Alt too low for local Az';
                    MountObj.LogFile.write('Target Alt too low for local Az');
                end
                if ~FlagRes.HA
                    MountObj.LastError = 'Target HA is out of range';
                    MountObj.LogFile.write('Target HA is out of range');
                end
            end
    end
    
end
