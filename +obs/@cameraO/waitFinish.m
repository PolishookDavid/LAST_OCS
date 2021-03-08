function Flag = waitFinish(CameraObj)
% wait until the camera ended exposing, readout, and writing image and returned to idle mode
   Flag = false;
   % Wait for 2 seconds so the previous command will start
   pause(0.01);
   InxDot = 0;
   while(strcmp(CameraObj.CamStatus, 'exposing') || strcmp(CameraObj.CamStatus, 'reading'))
      pause(0.01);
      if CameraObj.Verbose
         InxDot = InxDot + 1;
         if (mod(InxDot,100) == 0)
            fprintf('.')
         end
         if (mod(InxDot,6000) == 0)
            fprintf('\n')
         end
      end
   end
   pause(0.01);
   if (strcmp(CameraObj.CamStatus, 'idle'))
      if CameraObj.Verbose, fprintf('\n'); end
      CameraObj.notifyUser
      Flag = true;
   else
      CameraObj.LastError = ['A problem occurd with the camera. Status: ', C.CamStatus];
   end
end
