function flag=isHome(MountObj)
% check if the mount is at home position
   MountObj.checkIfConnected
   flag=MountObj.MouHn.isHome;
end
