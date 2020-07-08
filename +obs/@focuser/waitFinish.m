function Flag = waitFinish(Foc)
% wait until the focuser ended moving and returned to idle mode
   Flag = false;
   pause(2);
   while(strcmp(Foc.Status, 'moving'))
      pause(1);
      if Foc.Verbose, fprintf('.'); end
   end
   pause(1);
   if (strcmp(Foc.Status, 'idle'))
      if Foc.Verbose, fprintf('\nMoving focuser is complete\n'); end
      Flag = true;
   else
      if Foc.Verbose, fprintf('A problem has occurd with the focuser. Status: %s\n', Foc.Status); end
   end
end
