function Flag = waitFinish(CameraObj)
% wait until the camera ended exposing, readout, and writing image and returned to idle mode
   Flag = false;
   % Wait for 2 seconds so the previous command will start
   pause(2);
   while(strcmp(CameraObj.CamStatus, 'exposing') || strcmp(CameraObj.CamStatus, 'reading'))
      pause(1);
      if CameraObj.Verbose, fprintf('.'); end
   end
   pause(1);
   if (strcmp(CameraObj.CamStatus, 'idle'))
      if CameraObj.Verbose, fprintf('\n'); end
      CameraObj.notifyUser
      Flag = true;
   else
      CameraObj.LastError = ['A problem occurd with the camera. Status: ', C.CamStatus];
   end
end
