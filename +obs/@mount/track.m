function track(MountObj,rate)
% Start tracking.
% MountObj.track use sidereal rate.
% rate in degrees/sec between 4.1781e-04°/sec and 7.9383e-3°/sec
% rate = 0 stops the tracking.
   MountObj.checkIfConnected
   if nargin < 2
      MountObj.MouHn.track; % Driver will tarck at sidereal rate
      MountObj.LogFile.writeLog('call track')
   else
      MountObj.MouHn.track(rate);
      MountObj.LogFile.writeLog(sprintf('call track, rate = %.f',rate))
   end
end