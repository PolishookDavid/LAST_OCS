function callback_timer(MountObj, ~, ~)
% After slewing, check if mount is in Idle status 

flag = 'no';
if (~strcmp(MountObj.Status, 'slewing'))
   stop(MountObj.SlewingTimer);
   beep
   fprintf('Slewing is complete\n')
   flag = 'yes';
end
