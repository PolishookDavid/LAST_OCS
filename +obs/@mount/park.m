function park(MountObj,parking)
% parks the mount, if parking=true, unparks it if false
    if ~exist('parking','var')
        parking=true;
    end
    MountObj.LogFile.writeLog(sprintf('call parking = %d',parking))

    MountObj.lastError='';
    if (parking)
       MountObj.MinAltPrev = MountObj.MinAlt;
       MountObj.MinAlt = 0;

      % Start timer to notify when slewing is complete
      MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
      start(MountObj.SlewingTimer);

    else
       if(~isnan(MountObj.MinAltPrev))
          MountObj.MinAlt = MountObj.MinAltPrev;
          MountObj.MinAltPrev = NaN;
       end
    end
   MountObj.MouHn.park(parking);
   if (~isempty(MountObj.MouHn.lastError))
      MountObj.lastError=MountObj.MouHn.lastError;
      MountObj.LogFile.writeLog(MountObj.lastError)
      if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
   end
end
