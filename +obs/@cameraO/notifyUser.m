function notifyUser(CameraObj)
% Notify the user the exposure was finished, and the image was readout and downloaded

   beep;
   if (CameraObj.SaveOnDisk)
      if CameraObj.Verbose, fprintf('%s is written\n', CameraObj.LastImageName); end
   else
      if CameraObj.Verbose, fprintf('Temporal image is ready. Not written on disk\n'); end
   end

end