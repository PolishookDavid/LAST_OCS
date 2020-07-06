function Flag = waitFinish(Foc)
% wait until the focuser ended moving and returned to idle mode
   Flag = 0;
   while(strcmp(Foc.Status, 'moving'))
      pause(1);
      if Foc.Verbose, fprintf('.'); end
   end
   if (strcmp(Foc.Status, 'idle'))
      fprintf('\nMoving focuser is complete\n');
      Flag = 1;
   else
      fprintf('A problem has occurd with the focuser. Status: %s\n', Foc.Status)
   end
end
