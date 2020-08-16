function flag=isSlewing(MountObj)
% check if the mount is slewing
   if MountObj.checkIfConnected
    flag=MountObj.Handle.isSlewing;
   end
end
