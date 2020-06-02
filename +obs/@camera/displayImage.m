function displayImage(CameraObj)
% Display the last image taken according the settings.

   if (cameraObj.ToDisplay)
      imagesc(CameraObj.CameraDriverHndl.lastImage);hold on;plot(6388./2,9600./2,'k+', 'markersize', 20, 'linewidth', 1);
      axis equal;hold off;
   end

end