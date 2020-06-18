function home(MountObj)
% send the mount to its home position
   if (~strcmp(MountObj.Status, 'park'))

      % Start timer to notify when slewing is complete
      MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
      start(MountObj.SlewingTimer);
                  
      MountObj.MouHn.home;
      MountObj.LogFile.writeLog('Slewing home')
   else
      MountObj.lastError = "Cannot slew, telescope is parking. Run: park(0) to unpark";
      MountObj.LogFile.writeLog(MountObj.lastError)
      if MountObj.Verbose, fprintf('%s\n', MountObj.lastError); end
   end
end
