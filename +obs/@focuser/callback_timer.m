function callback_timer(Foc, ~, ~)
% After slewing, check if mount is in Idle status 

if (strcmp(Foc.Status, 'idle'))
   stop(Foc.FocusMotionTimer);
   beep
   Foc.LogFile.writeLog('Focuser reached destination')
   if Foc.Verbose, fprintf('Focuser reached destination\n'); end
end
