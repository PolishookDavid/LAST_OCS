function Flag = waitFinish(MountObj)
% wait until the mount ended slewing and returned to idle mode
   Flag = 0;
   while(strcmp(MountObj.Status, 'slewing'))
      pause(1);
      if MountObj.Verbose, fprintf('.'); end
   end
   if (strcmp(MountObj.Status, 'idle') | strcmp(MountObj.Status, 'tracking'))
      fprintf('\nSlewing is complete\n');
      Flag = 1;
   else
      fprintf('A problem has occurd with the mount. Status: %s\n', MountObj.Status)
   end
end
