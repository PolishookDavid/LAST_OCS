function Flag=isHome(MountObj)
    % check if the mount is at home position as defined by the driver

    if MountObj.IsConnected && obs.mount.ismountDriver(MountObj.Handle)
        Flag=MountObj.Handle.isHome;
    else
        Flag = false;
        MountObj.LogFile.writeLog('isHome: Mount is not connected');
        MountObj.LastError = 'isHome: Mount is not connected';
        if MountObj.Verbose
            fprintf('isHome: Mount is not connected');
        end
    end
end
