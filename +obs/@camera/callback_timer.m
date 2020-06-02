function callback_timer(CameraObj, ~, ~)

flag = 'no';
if (strcmp(CameraObj.CamStatus, 'idle'))
   % Get image and data from driver
%   CameraObj.LastImage = CameraObj.CameraDriverHndl.lastImage;
   % Stop timer
    stop(CameraObj.ReadoutTimer);
%    delete(CameraObj.ReadoutTimer)
   
   % Save the image according to setting.
   CameraObj.saveCurImage;

   % Notify the user by sound and comment
   CameraObj.notifyUser;

   % Display the image according to setting.
   CameraObj.displayImage;

   flag = 'yes';
end

