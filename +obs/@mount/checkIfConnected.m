function flag=checkIfConnected(MountObj, Text)
% check if the mount is connected
   flag = MountObj.isConnected;
   if flag
      % Mount is connected, continue with no action
   else
      if nargin<2
         Text = sprintf("Mount %s is disconnected", util.readSystemConfigFile('MountGeoName'));
         if MountObj.Verbose, fprintf('%s\n', Text); end
      end
      % Try to reconnect to mount
      if MountObj.Verbose, fprintf('Try to reconnect to mount\n'); end
      MountObj.connect;
      pause(5)
      flag = MountObj.isConnected;
      if flag
         % Mount is connected, continue with no action
      else
         % Wait for a minute and try again to connect
         if MountObj.Verbose, fprintf('Wait 60 sec and try to reconnect to mount\n'); end
         pause(60)
         MountObj.connect;
         pause(5)
         flag = MountObj.isConnected;
         if flag
            % Mount is connected, continue with no action
         else
            if nargin<2
               Text = sprintf("Mount %s is disconnected", util.readSystemConfigFile('MountGeoName'));
            end
            MountObj.lastError = Text;
            MountObj.LogFile.writeLog(Text)
            if MountObj.Verbose, fprintf('%s\n', Text); end
            error(Text)
            % Send email
            % Call the police
            % Fire at will, commander
         end
      end
   end
end
