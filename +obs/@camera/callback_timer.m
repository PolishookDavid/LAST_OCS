function callback_timer(CameraObj, ~, ~)

if (strcmp(CameraObj.CamStatus, 'idle'))
   % Stop timer
    stop(CameraObj.ReadoutTimer);
%    delete(CameraObj.ReadoutTimer)
   
   % Save the image according to setting.
   if (CameraObj.SaveOnDisk)
      CameraObj.saveCurImage;
   end

   % DP: remove from here and enter to waitFinish
%   % Notify the user by sound and comment
%   CameraObj.notifyUser;

   % Display the image according to setting.
   if (CameraObj.Display)
      CameraObj.displayImage;
   end
end

