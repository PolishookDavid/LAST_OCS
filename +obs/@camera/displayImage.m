function displayImage(CameraObj)
% Display the last image taken according the settings.

   if (strcmpi(CameraObj.Display, 'matlab'))
      % Choose figure number to display
      if(CameraObj.DisplayMatlabFig > 0)
         figure(CameraObj.DisplayMatlabFig)
      else
         figure
         H=gcf;
         CameraObj.DisplayMatlabFig = H.Number;
      end

      imagesc(CameraObj.LastImage);
      hold on;
      plot(6388./2,9600./2,'k+', 'markersize', 20, 'linewidth', 1);
      axis equal;
      hold off;
      title(strrep(CameraObj.LastImageName,'_','\_'))
   elseif(strcmpi(CameraObj.Display, 'ds9'))
       ds9(CameraObj.LastImage, 'frame', CameraObj.CameraNum)
   else
      if CameraObj.Verbose
          fprintf('Image viewer is unknown: %s.\n', lower(CameraObj.Display));
      end
   end
end