function displayImage(CameraObj)
% Display the last image taken according to the object properties.
% The object properties that control the display are:
% 'Display' - {'ds9','matlab'}
% 'DisplayReducedIm' - Divide by flat
% The display property is either 'matlab' or 'ds9'


   ImageToDisplay = CameraObj.LastImage;
   
   % Remove temporary flat field for display
   if (CameraObj.DisplayReducedIm)
%      ImageToDisplay = removeFlatForDisplay;
      
      % PATCH - TO REMOVE AFTER ONE GIT PULL ... OTHERWISE IT DOES NOT
      % RECOGNIZE removeFlatForDisplay
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % This is the content of removeFlatForDisplay:
      ImageToDisplay = single(ImageToDisplay);

      OrigDir = pwd;
      cd /media/last/data2/ServiceImages
      Dark = FITS.read2sim('Dark.fits');
      S = load('Flat.mat');  % need to update the image
      cd(OrigDir);
      Flat = S.Flat;
      Flat.Im = Flat.Im./nanmedian(Flat.Im,'all');
      
      ImageToDisplay = ImageToDisplay(:,1:6387);
      Flat.Im        = Flat.Im(:,1:6387);
      
      ImageToDisplay = (ImageToDisplay - Dark.Im)./Flat.Im;
      
      
   end
   
   switch lower(CameraObj.Display)
       case 'matlab'
           
          % Choose figure number to display
          if(CameraObj.DisplayMatlabFig > 0)
             figure(CameraObj.DisplayMatlabFig)
          else
             figure
             H=gcf;
             CameraObj.DisplayMatlabFig = H.Number;
          end

          imagesc(ImageToDisplay);
          hold on;
          plot(6388./2,9600./2,'k+', 'markersize', 20, 'linewidth', 1);
          axis equal;
          hold off;
          title(strrep(CameraObj.LastImageName,'_','\_'))
       case 'ds9'
           % Display in ds9 each camera in a different frame
           ds9(ImageToDisplay, 'frame', CameraObj.CameraNum)
           
           if (CameraObj.DisplayAllImage)
              ZoomValue = CameraObj.DisplayZoomValueAllImage;
           else
              ZoomValue = CameraObj.DisplayZoomValue;
           end
           ds9.zoom(ZoomValue, ZoomValue);

       otherwise
          if CameraObj.Verbose
              fprintf('Image viewer is unknown: %s.\n', lower(CameraObj.Display));
          end
   
   end
end