function success=disconnect(MountObj)
   if MountObj.checkIfConnected
      MountObj.LogFile.writeLog('call mount.disconnect')
      try
         MountObj.Handle.disconnect;
         MountObj.IsConnected = false;
         success = true;
      catch
         MountObj.LastError = 'mount.disconnect failed';
      end
   end
end
