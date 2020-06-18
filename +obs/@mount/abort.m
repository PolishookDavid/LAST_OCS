function abort(MountObj)
% emergency stop
   % restored limitation on minimal altitude
   if(~isnan(MountObj.MinAltPrev))
       MountObj.MinAlt = MountObj.MinAltPrev;
       MountObj.MinAltPrev = NaN;
   end
   % Delete the timer
   delete(MountObj.SlewingTimer);
   % Stop the mount motion
   MountObj.MouHn.abort;
   MountObj.LogFile.writeLog('Abort slewing')
end
