function disconnect(F)
% close the serial stream, but don't delete it from workspace
   if (~isempty(F.FocHn.lastError))
      if(strfind(F.FocHn.lastError, 'could not get status, communication problem?'))
         F.lastError = F.FocHn.lastError;
      elseif(strfind(F.FocHn.lastError, 'cannot delete Port object'))
         F.lastError = F.FocHn.lastError;
      elseif (strfind(F.FocHn.lastError, 'cannot create Port object'))
         F.lastError = F.FocHn.lastError;
      elseif (strfind(F.FocHn.lastError, 'cannot be opened'))
         F.lastError = F.FocHn.lastError;
      else
         F.FocHn.disconnect;
      end
   else
       if (strcmp(F.Status, 'unknown'))
          F.lastError = 'Communication problems?';
          fprintf('Communication problems? Check cables!\n')
       else
          F.FocHn.disconnect;
       end
   end
end
