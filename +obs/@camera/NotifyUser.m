function NotifyUser(CameraObj)
% Notify the user the exposure was finished, and the image was readout and downloaded

Beep;
fprintf('Image %s is ready\n', CameraObj.lastImageName)

% NOT READY YET - DP, Mar 16, 2020


end