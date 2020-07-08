function flag=checkIfConnected(MountObj, Text)
% check if the mount is connected
   flag = MountObj.IsConnected;
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
      flag = MountObj.IsConnected;
      if flag
         % Mount is connected, continue with no action
      else
         % Wait for a minute and try again to connect
         WaitingTime = 30;
         if MountObj.Verbose, fprintf('Wait %.2f sec and try to reconnect to mount\n', WaitingTime); end
         pause(WaitingTime)
         MountObj.connect;
         pause(5)
         flag = MountObj.IsConnected;
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
