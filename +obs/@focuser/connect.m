function F=connect(F)
% connect to a focus motor on the specified Port, try all ports if
%  Port omitted
    F.FocuserDriverHndl.connect;
    if (~isempty(F.FocuserDriverHndl.lastError)),
       if(strfind(F.FocuserDriverHndl.lastError, 'cannot delete Port object'))
          F.lastError = F.FocuserDriverHndl.lastError;
       elseif (strfind(F.FocuserDriverHndl.lastError, 'cannot create Port object'))
          F.lastError = F.FocuserDriverHndl.lastError;
       elseif (strfind(F.FocuserDriverHndl.lastError, 'cannot be opened'))
          F.lastError = F.FocuserDriverHndl.lastError;
       elseif (strfind(F.FocuserDriverHndl.lastError, 'could not get status, communication problem?'))
          F.lastError = F.FocuserDriverHndl.lastError;
          fprintf('Communication problems? Check cables!\n')
       end
    else
       F.lastError = 'Communication problems?';
       fprintf('Communication problems? Check cables!\n')
    end
end
