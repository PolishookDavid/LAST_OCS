function flag=isSlewing(MountObj)
% check if the mount is slewing
    flag=MountObj.MountDriverHndl.isSlewing()
end
