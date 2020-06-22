function flag=checkIfConnected(CameraObj, Text)
% check if the camera is connected
   flag = CameraObj.isConnected;
   if flag
      % Camera is connected, continue with no action
   else
      if nargin<2
         Text = sprintf("Camera %s is disconnected", util.readSystemConfigFile('CameraGeoName'));
         if CameraObj.Verbose, fprintf('%s\n', Text); end
      end
      % Try to reconnect to mount
      if CameraObj.Verbose, fprintf('Try to reconnect to camera\n'); end
      CameraObj.connect;
      pause(5)
      flag = CameraObj.isConnected;
      if flag
         % Camera is connected, continue with no action
      else
         % Wait for a minute and try again to connect
         if CameraObj.Verbose, fprintf('Wait 30 sec and try to reconnect to camera\n'); end
         pause(30)
         CameraObj.connect;
         pause(5)
         flag = CameraObj.isConnected;
         if flag
            % Camera is connected, continue with no action
         else
            if nargin<2
               Text = sprintf("Camera %s is disconnected", util.readSystemConfigFile('CameraGeoName'));
            end
            CameraObj.lastError = Text;
            CameraObj.LogFile.writeLog(Text)
            if CameraObj.Verbose, fprintf('%s\n', Text); end
            error(Text)
            % Send email
            % Call the police
            % Fire at will, commander
         end
      end
   end
end
