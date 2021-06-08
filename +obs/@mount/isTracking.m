function Flag=isTracking(MountObj)
    % check if the mount is tracking

    if MountObj.IsConnected  && obs.mount.ismountDriver(MountObj.Handle)
        Flag = MountObj.Handle.isTracking;
    end
end
