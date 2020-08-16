function callback_timer(Focuser, ~, ~)
% After slewing, check if mount is in Idle status 

if (strcmp(Focuser.Status, 'idle'))
   stop(Focuser.FocusMotionTimer);
   beep
   Focuser.LogFile.writeLog('Focuser reached destination')
%   if Focuser.Verbose, fprintf('Focuser reached destination\n'); end
end
