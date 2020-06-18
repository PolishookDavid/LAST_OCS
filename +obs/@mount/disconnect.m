function disconnect(MountObj)
    MountObj.MouHn.disconnect();
    MountObj.LogFile.writeLog('Disconnecting mount')
end
