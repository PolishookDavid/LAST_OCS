function park(MountObj,parking)
% parks the mount, if parking=true, unparks it if false
    if ~exist('parking','var')
        parking=true;
    end
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
   MountObj.MountDriverHndl.park(parking);
   MountObj.lastError=MountObj.MountDriverHndl.lastError;
end
