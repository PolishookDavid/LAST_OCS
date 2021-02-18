function home(MountObj)
% send the mount to its home position
   if MountObj.checkIfConnected

      if (~strcmp(MountObj.Status, 'park'))

         MountObj.LogFile.writeLog('Slewing home')

         MountObj.Handle.home;

         % Start timer to notify when slewing is complete
         MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
         start(MountObj.SlewingTimer);

      else
         MountObj.LastError = "Cannot slew, telescope is parking. Run: park(0) to unpark";
      end
   end
end
