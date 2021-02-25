function HourAngle=HA(MountObj, HA)
   % set/get hour angle (HA).
   % set will move the telescope!
   % HA is in degrees
   % Functionality from MAAT library

   if MountObj.checkIfConnected
      MountObj.LogFile.writeLog('call HA')
      RAD = 180./pi;
      % Get JD from the computer
      JD = celestial.time.julday;
      LST = celestial.time.lst(JD,MountObj.MountCoo.ObsLon./RAD);  % fraction of day
      if (nargin == 1)
         HourAngle = LST.*360 - MountObj.RA;
      elseif (nargin == 2)
         RA = mod(LST.*360 - HA, 360);
         MountObj.RA = RA;
      end
   end
end
        
