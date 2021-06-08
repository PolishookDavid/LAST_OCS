function Flag=isSlewing(MountObj)
    % check if the mount is slewing

    if MountObj.IsConnected  && obs.mount.ismountDriver(MountObj.Handle)
        Flag=MountObj.Handle.isSlewing;
    else
        Flag = false;
        MountObj.LogFile.writeLog('isSlewing: Mount is not connected');
        MountObj.LastError = 'isSlewing: Mount is not connected';
        if MountObj.Verbose
            fprintf('isSlewing: Mount is not connected');
        end
   end
end
