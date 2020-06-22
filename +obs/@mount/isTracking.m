function flag=isTracking(MountObj)
% check if the mount is tracking
   MountObj.checkIfConnected
   flag = MountObj.MouHn.isTracking;
end
