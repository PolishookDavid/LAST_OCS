function [DistRA,DistDec,Aux]=GoTo(MountObj, Long, Lat, varargin)
% Send mount to coordinates/name
% Package: mount
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
% Output : - Apparent R.A.
%          - Apparent Dec.
%          - A structure containing the intermidiate values.
% License: GNU general public license version 3
%     By : David Polishook                    Feb 2020
% Example: [DistRA,DistDec,Aux]=mount.GoTo(10,50)
%          mount.GoTo(10,50,'InCooType','a')
%          mount.GoTo('10:00:00','+50:00:00');
%          mount.GoTo('M31');
%          mount.GoTo('9804;',[],'NameServer','jpl')
%--------------------------------------------------------------------------


% Convert input into RA/Dec
[RA, Dec] = celestial.coo.convert2equatorial(Long, Lat, varargin{:})
if(~isnan(RA) & ~isnan(Dec)),
   MountObj.MountDriverHndl.GoTo(RA, Dec, 'eq');
   MountObj.lastError = MountObj.MountDriverHndl.lastError;
else
    fprintf('Could not find coordinates\n')
end

end
            
