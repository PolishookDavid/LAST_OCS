function callback_timer(MountObj, ~, ~)
% After slewing, check if mount is in Idle status 

if (~strcmp(MountObj.Status, 'slewing'))
   stop(MountObj.SlewingTimer);
   beep
   MountObj.LogFile.writeLog('Slewing is complete')
%   if MountObj.Verbose, fprintf('Slewing is complete\n'); end
end
