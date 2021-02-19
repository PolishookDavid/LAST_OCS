function [Flag,RA,Dec,Aux]=goto(MountObj, Long, Lat, varargin)
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
%     By : David Polishook                    Feb 2020
% Example: [DistRA,DistDec,Aux]=mount.goto(10,50)
%          mount.goto(10,50,'InCooType','a')
%          mount.goto('10:00:00','+50:00:00');
%          mount.goto('M31');
%          mount.goto('9804;',[],'NameServer','jpl')
%--------------------------------------------------------------------------

RAD = 180./pi;

if nargin<3
    Lat = [];
end


JD = celestial.time.julday;

Flag = false;

if MountObj.checkIfConnected

   % Do not slew if parking, first do unpark using MountObj.park(0)
   if (~strcmp(MountObj.Status, 'park'))

      % Convert input into RA/Dec [input deg, output deg]
      EquinoxOfDate = sprintf('J%8.3f',convert.time(JD,'JD','J'));
      
      [RA, Dec, Aux] = celestial.coo.convert2equatorial(Long, Lat, varargin{:},'OutCooType',EquinoxOfDate);
      
      if(~isnan(RA) && ~isnan(Dec))

         % check that target is visible
         % note that input is in [rad]
         
         [Flag,FlagRes,Data] = celestial.coo.is_coordinate_ok(RA./RAD, Dec./RAD, JD, ...
                                                              'Lon', MountObj.MountCoo.ObsLon./RAD, ...
                                                              'Lat', MountObj.MountCoo.ObsLat./RAD, ...
                                                              'AltMinConst', MountObj.MinAlt./RAD,...
                                                              'AzAltConst', MountObj.MinAzAltMap./RAD);
         
         if (Flag)


            % Start slewing
            MountObj.Handle.goTo(RA, Dec, 'eq');

            % compare coordinates to requested coordinates
            
            % Get error
            MountObj.LastError = MountObj.Handle.LastError;

            % Delete calling a timer to wait for slewing complete,
            % because a conflict with Xerexs. DP Feb 8, 2021
             % Start timer to notify when slewing is complete
             MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
             start(MountObj.SlewingTimer);

         else
            if (~FlagRes.Alt)
               MountObj.LastError = 'Target Alt too low';
            else
               if (~FlagRes.AzAlt)
                  MountObj.LastError = 'Target Alt too low for the local Az';
               end
            end
            if(~FlagRes.HA)
               MountObj.LastError = 'HA too large. Check if mount is calibrated';
            end
         end
      else
         MountObj.LastError = 'Could not find coordinates';
      end
   else
      MountObj.LastError = "Cannot slew, telescope is parking. Run: park(0) to unpark";
   end          
end
