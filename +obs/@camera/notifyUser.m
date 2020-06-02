function notifyUser(CameraObj)
% Notify the user the exposure was finished, and the image was readout and downloaded

beep;
if (CameraObj.SaveOnDisk)
   fprintf('Image %s is ready\n', CameraObj.LastImageName)
else
   fprintf('Temporal image is ready. Not written on disk\n')
end

% NOT READY YET - DP, Mar 16, 2020

end