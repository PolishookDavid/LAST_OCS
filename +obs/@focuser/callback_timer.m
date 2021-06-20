function callback_timer(Focuser, ~, ~)
% After slewing, check if mount is in Idle status 
%  (attempting to supersede such timer calls!)

if (strcmp(Focuser.Status, 'idle'))
   stop(Focuser.FocusMotionTimer);
   beep
   Focuser.LogFile.writeLog('Focuser reached destination')
%   if Focuser.Verbose, fprintf('Focuser reached destination\n'); end
elseif (strcmp(Focuser.Status, 'unknown'))
   stop(Focuser.FocusMotionTimer);
   beep; beep;
   Focuser.LogFile.writeLog('Focuser status is unknown')
   if Focuser.Verbose, fprintf('Focuser status is unknown\n'); end
end
