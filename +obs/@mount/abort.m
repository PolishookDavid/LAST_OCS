function abort(MountObj)
    % emergency stop
    if MountObj.IsConnected

        MountObj.LogFile.writeLog('Abort mount slewing')

        % Stop the mount motion through the driver object
        MountObj.Handle.abort;

        % Delete the slewing timer
        delete(MountObj.SlewingTimer);
    end
end
