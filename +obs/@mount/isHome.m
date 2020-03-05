function flag=isHome(MountObj)
% check if the mount is at home position
    flag=MountObj.MountDriverHndl.isHome;
end
