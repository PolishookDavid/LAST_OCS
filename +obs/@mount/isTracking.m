function flag=isTracking(MountObj)
% check if the mount is tracking
   if MountObj.checkIfConnected
      flag = MountObj.Handle.isTracking;
   end
end
