function Flag = waitFinish(CameraObj)
% wait until the camera ended exposing, readout, and writing image and returned to idle mode
   Flag = 0;
   while(strcmp(CameraObj.CamStatus, 'exposing') || strcmp(CameraObj.CamStatus, 'reading'))
      pause(1);
      if CameraObj.Verbose, fprintf('.'); end
   end
   if (strcmp(CameraObj.CamStatus, 'idle'))
      fprintf('\n');
      CameraObj.notifyUser
      Flag = 1;
   else
      fprintf('A problem occurd with the camera. Status: %s\n', CameraObj.CamStatus)
   end
end
