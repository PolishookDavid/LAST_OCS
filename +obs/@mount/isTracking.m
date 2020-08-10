function flag=isTracking(MountObj)
% check if the mount is tracking
   if MountObj.checkIfConnected
      flag = MountObj.MouHn.isTracking;
   end
end
