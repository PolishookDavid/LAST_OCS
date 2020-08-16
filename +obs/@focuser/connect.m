function success=connect(Focuser)
% Connect to a focus motor
    success = 0;
    Focuser.Handle.connect;
    Focuser.LogFile.writeLog('Connecting to focuser.')
    Focuser.LogFile.writeLog(sprintf('Current focus position: %d',Focuser.Pos));


    % Get name and type
    Focuser.FocuserUniqueName = obs.util.config.readSystemConfigFile('FocuserUniqueName');
    Focuser.FocuserType = Focuser.Handle.FocType;

    if (isempty(Focuser.Handle.lastError))
       success = 1;
    end
    Focuser.LastError = Focuser.Handle.lastError;
end
