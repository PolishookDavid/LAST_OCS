function disconnect(MountObj)
   MountObj.checkIfConnected
   MountObj.MouHn.disconnect;
   MountObj.isConnected = false;
   MountObj.LogFile.writeLog('Disconnecting mount')
end
