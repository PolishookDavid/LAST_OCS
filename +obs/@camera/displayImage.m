function displayImage(CameraObj)
% Display the last image taken according the settings.

   if (strcmpi(CameraObj.Display, 'matlab'))
      imagesc(CameraObj.CamHn.lastImage);
      hold on;
      plot(6388./2,9600./2,'k+', 'markersize', 20, 'linewidth', 1);
      axis equal;
      hold off;
   elseif(strcmpi(CameraObj.Display, 'ds9'))
       ds9(CameraObj.CamHn.lastImage)
   else
      if CameraObj.Verbose, fprintf('Image viewer is unknown: %s.\n', lower(CameraObj.Display)); end
   end
end