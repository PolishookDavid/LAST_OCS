function HourAngle=HA(MountObj)
   % SOMETHING IS WRONG HERE... - DP 2020 MAR 5
   HourAngle = NaN;
   % Functionality from MAAT library
   RAD = 180./pi;
   % Get JD from the computer
   JD = celestial.time.julday;
   LST = celestial.time.lst(JD,MountObj.MountCoo.ObsLon./RAD)  % fraction of day
   HourAngle = LST.*360 - MountObj.RA;
end
        
