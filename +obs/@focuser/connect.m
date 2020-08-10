function success=connect(Foc)
% Connect to a focus motor
    success = 0;
    Foc.FocHn.connect;
    Foc.LogFile.writeLog('Connecting to focuser.')
    Foc.LogFile.writeLog(sprintf('Current focus position: %d',Foc.Pos));


    % Get name and type
    Foc.FocUniqueName = obs.util.config.readSystemConfigFile('FocUniqueName');
    Foc.FocType = Foc.FocHn.FocType;

    if (isempty(Foc.FocHn.lastError))
       success = 1;
    end
    Foc.LastError = Foc.FocHn.lastError;
end
