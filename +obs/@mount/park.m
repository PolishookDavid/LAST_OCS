function park(MountObj,parking)
% parks the mount, if parking=true, unparks it if false
   if nargin < 2
      parking=true;
   end
   
   if MountObj.checkIfConnected
      MountObj.LogFile.writeLog(sprintf('call parking = %d',parking))

      if (parking)
         MountObj.MinAltPrev = MountObj.MinAlt;
         MountObj.MinAlt = 0;


         % Delete calling a timer to wait for slewing complete,
         % because a conflict with Xerexs. DP Feb 8, 2021
%          % Start timer to notify when slewing is complete
%          MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
%          start(MountObj.SlewingTimer);

      else
         if(~isnan(MountObj.MinAltPrev))
            MountObj.MinAlt = MountObj.MinAltPrev;
            MountObj.MinAltPrev = NaN;
         end
      end
      MountObj.Handle.park(parking);
      MountObj.LastError = MountObj.Handle.LastError;
   end
end
