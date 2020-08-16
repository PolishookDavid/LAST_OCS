function Flag = waitFinish(Focuser)
% wait until the focuser ended moving and returned to idle mode
   Flag = false;
   pause(2);
   while(strcmp(Focuser.Status, 'moving'))
      pause(1);
      if Focuser.Verbose, fprintf('.'); end
   end
   pause(1);
   if (strcmp(Focuser.Status, 'idle'))
      if Focuser.Verbose, fprintf('\nMoving focuser is complete\n'); end
      Flag = true;
   else
      if Focuser.Verbose, fprintf('A problem has occurd with the focuser. Status: %s\n', Focuser.Status); end
   end
end
