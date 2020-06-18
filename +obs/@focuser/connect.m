function success=connect(Foc)
% Connect to a focus motor
    success = 0;
    Foc.FocHn.connect;
    Foc.LogFile.writeLog('Connecting to focuser.')
    Foc.LogFile.writeLog(sprintf('Current focus position: %d',Foc.Pos));


    % Get name and type
    Foc.FocUniqueName = util.readSystemConfigFile('FocUniqueName');
    Foc.FocType = Foc.FocHn.FocType;
    
    if (~isempty(Foc.FocHn.lastError))
       if(strfind(Foc.FocHn.lastError, 'cannot delete Port object'))
          Foc.lastError = Foc.FocHn.lastError;
       elseif (strfind(Foc.FocHn.lastError, 'cannot create Port object'))
          Foc.lastError = Foc.FocHn.lastError;
       elseif (strfind(Foc.FocHn.lastError, 'cannot be opened'))
          Foc.lastError = Foc.FocHn.lastError;
       elseif (strfind(Foc.FocHn.lastError, 'could not get status, communication problem?'))
          Foc.lastError = Foc.FocHn.lastError;
          fprintf('Communication problems? Check cables!\n')
       end
    else
%        Foc.lastError = 'Communication problems?';
%        fprintf('Communication problems? Check cables!\n')
       success = 1;
    end
end
