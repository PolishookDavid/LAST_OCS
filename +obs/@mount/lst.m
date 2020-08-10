function LST=lst(MountObj)
   % Get the Local Siderial Time (LST).
   % LST is in degrees
   % Functionality from MAAT library

   if MountObj.checkIfConnected
      RAD = 180./pi;
      % Get JD from the computer
      JD = celestial.time.julday;
      LST = celestial.time.lst(JD,MountObj.MountCoo.ObsLon./RAD);  % fraction of day
      LST = LST.*360;
   end
end
