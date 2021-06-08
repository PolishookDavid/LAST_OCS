function Success=disconnect(MountObj)
    % disconnect a mount object including the driver

    if MountObj.IsConnected
        MountObj.LogFile.writeLog('call mount.disconnect')
         try
            MountObj.Handle.disconnect;
            MountObj.IsConnected = false;
            Success = true;
         catch
            MountObj.LogFile.writeLog('mount.disconnect failed')
            MountObj.LastError = 'mount.disconnect failed';
         end
    else
        MountObj.LogFile.writeLog('can not disconnect mount because IsConnected=false')
        MountObj.LastError = 'can not disconnect mount because IsConnected=false';
    end
    if ~isempty(MountObj.LogFile)
        %MountObj.LogFile.delete;
        %MountObj.LogFile = [];
    end

end   
