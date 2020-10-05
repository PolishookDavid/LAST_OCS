function success=connect(Focuser,Port)
% Connect to a focus motor
    success = 0;
    if nargin == 1
       Focuser.Handle.connect;
    elseif(nargin == 2)
       Focuser.Handle.connect(Port);
    end
    Focuser.LogFile.writeLog('Connecting to focuser.')
    Focuser.LogFile.writeLog(sprintf('Current focus position: %d',Focuser.Pos));


    % Get name and type
    Focuser.FocuserUniqueName = obs.util.config.readSystemConfigFile('FocuserUniqueName');
    Focuser.FocuserType = Focuser.Handle.FocType;

    if (isempty(Focuser.Handle.LastError))
       success = 1;
    end
    Focuser.LastError = Focuser.Handle.LastError;
end
