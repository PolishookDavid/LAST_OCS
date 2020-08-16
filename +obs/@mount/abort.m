function abort(MountObj)
% emergency stop
   if MountObj.checkIfConnected

      MountObj.LogFile.writeLog('Abort slewing')

      % Stop the mount motion through the driver object
      MountObj.Handle.abort;

      % restored limitation on minimal altitude
      if(~isnan(MountObj.MinAltPrev))
         MountObj.MinAlt = MountObj.MinAltPrev;
         MountObj.MinAltPrev = NaN;
      end
      
      % Delete the slewing timer
      delete(MountObj.SlewingTimer);
   end
end
