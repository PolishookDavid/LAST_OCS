function flag=isHome(MountObj)
% check if the mount is at home position
   if MountObj.checkIfConnected
      flag=MountObj.MouHn.isHome;
   end
end
