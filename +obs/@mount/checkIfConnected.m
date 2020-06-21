function flag=checkIfConnected(MountObj, Text)
% check if the mount is connected
   flag = MountObj.isConnected;
   1111
   if flag
       2222
      % Mount is connected, continue with no action
   else
       3333
      % Try to reconnect to mount
      MountObj.connect
      if MountObj.isConnected
         % Mount is connected, continue with no action
      else
         % Wait for a minute and try again to connect
         pause(60)
         MountObj.connect
         if MountObj.isConnected
            % Mount is connected, continue with no action
         else
            if vargin<2
               Text = "Mount is disconnected";
            end
            MountObj.lastError = Text;
            MountObj.LogFile.writeLog(Text)
            if MountObj.Verbose, fprintf('%s\n', Text); end
            % Send email
            % Call the police
            % Fire at will, commander
         end
      end
   end
end
