function NotifyUser(CameraObj)
% supposed to be a blocking function
% writing this only because I'm asked for. For the QHY it doesn't make
%  too much sense because the camera status is guessed and maintained as
%  class state variables, not read querying the camera. For other cameras
%  it could make sense. The QHY does not return to idle by itself, they do
%  only after reading or aborting exposure

% After image was taken do the following

% Save the image according to setting.
CameraObj.SaveCurImage;

% Notify the user by sound and comment
CameraObj.NotifyUser;

% Display the image according to setting.
CameraObj.DisplayImage;


end