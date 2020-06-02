function home(MountObj)
% send the mount to its home position
   if (~strcmp(MountObj.Status, 'park'))

      % Start timer to notify when slewing is complete
      MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
      start(MountObj.SlewingTimer);
                  
      MountObj.MountDriverHndl.home;
   else
      MountObj.lastError = "Telescope is parking. Run: park(0)";
      fprintf('%s\n', MountObj.lastError)
   end
end
