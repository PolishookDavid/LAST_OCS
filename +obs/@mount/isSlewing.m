function flag=isSlewing(MountObj)
% check if the mount is slewing
   if MountObj.checkIfConnected
    flag=MountObj.MouHn.isSlewing;
   end
end
