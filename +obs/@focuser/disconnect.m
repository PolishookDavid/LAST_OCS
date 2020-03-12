function disconnect(F)
% close the serial stream, but don't delete it from workspace
   if (~isempty(F.FocuserDriverHndl.lastError))
      if(strfind(F.FocuserDriverHndl.lastError, 'could not get status, communication problem?'))
         F.lastError = F.FocuserDriverHndl.lastError;
      elseif(strfind(F.FocuserDriverHndl.lastError, 'cannot delete Port object'))
         F.lastError = F.FocuserDriverHndl.lastError;
      elseif (strfind(F.FocuserDriverHndl.lastError, 'cannot create Port object'))
         F.lastError = F.FocuserDriverHndl.lastError;
      elseif (strfind(F.FocuserDriverHndl.lastError, 'cannot be opened'))
         F.lastError = F.FocuserDriverHndl.lastError;
      else
         F.FocuserDriverHndl.disconnect;
      end
   else
       if (strcmp(F.Status, 'unknown')),
          F.lastError = 'Communication problems?';
          fprintf('Communication problems? Check cables!\n')
       else
          F.FocuserDriverHndl.disconnect;
       end
   end
end
