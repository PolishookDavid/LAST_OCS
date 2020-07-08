function disconnect(MountObj)
%%%   MountObj.checkIfConnected
   MountObj.MouHn.disconnect;
   MountObj.IsConnected = false;
   MountObj.LogFile.writeLog('Disconnecting mount')
end
