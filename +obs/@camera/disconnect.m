function Success=disconnect(CameraObj)
   % Close the connection with the camera registered in the current camera object

   N = numel(CameraObj);
   for I=1:1:N
       if CameraObj(I).IsConnected

          % Call disconnect using the camera handle object
          Success(I) = CameraObj(I).Handle.disconnect;
          CameraObj(I).IsConnected = ~Success;

          CameraObj(I).LogFile.writeLog(sprintf('Disconnect CameraName: %s',CameraObj(I).CameraName));
          if ~isempty(CameraObj(I).LogFile)
              %CameraObj(I).LogFile.delete;
          end
       end
   end
end

