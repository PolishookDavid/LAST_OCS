function flag=isTracking(MountObj)
% check if the mount is tracking
    flag = MountObj.MountDriverHndl.isTracking();
end
