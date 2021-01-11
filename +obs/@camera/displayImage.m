function displayImage(CameraObj)
% Display the last image taken according the settings.

   ImageToDisplay = CameraObj.LastImage;
   % Remove temporary flat field for display
   if (CameraObj.DisplayReducedIm)
%      ImageToDisplay = removeFlatForDisplay;
      
      % PATCH - TO REMOVE AFTER ONE GIT PULL ... OTHERWISE IT DOES NOT
      % RECOGNIZE removeFlatForDisplay
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % This is the content of removeFlatForDisplay:
      TempIm = im2single(CameraObj.LastImage);

      OrigDir = pwd;
      cd /media/last/data2/ServiceImages
      DarkFile=FITS.read2sim('Dark.fits');
%      TempIm = TempIm - DarkFile.Im;
      
%      FlatTemp=FITS.read2sim('NormalizedFlatField_Temp.fits');
      S = load('Flat.mat');
      FlatTemp = S.Flat;
      FlatTemp.Im = FlatTemp.Im./mean(mean(FlatTemp.Im));
      ImageToDisplay = TempIm./FlatTemp.Im;
      cd (OrigDir);
   end
   
   if (strcmpi(CameraObj.Display, 'matlab'))
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
   elseif(strcmpi(CameraObj.Display, 'ds9'))
       % Display in ds9 each camera in a different frame
       ds9(ImageToDisplay, 'frame', CameraObj.CameraNum)
       if (CameraObj.DisplayAllImage)
          ZoomValue = CameraObj.DisplayZoomValueAllImage;
       else
          ZoomValue = CameraObj.DisplayZoomValue;
       end
       ds9.zoom(ZoomValue, ZoomValue);

   else
      if CameraObj.Verbose
          fprintf('Image viewer is unknown: %s.\n', lower(CameraObj.Display));
      end
   end
end