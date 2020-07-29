function disconnect(MountObj)
   if MountObj.checkIfConnected
      MountObj.MouHn.disconnect;
      MountObj.IsConnected = false;
      MountObj.LogFile.writeLog('Disconnecting mount')
   end
end
