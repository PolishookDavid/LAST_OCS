function flag=isSlewing(MountObj)
% check if the mount is slewing
   MountObj.checkIfConnected;
   flag=MountObj.MouHn.isSlewing;
end
