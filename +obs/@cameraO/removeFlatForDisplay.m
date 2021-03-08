function TempIm = removeFlatForDisplay(CameraObj)
% Remove a temporary normalized flat field image for better display.

   OrigDir = pwd;
   cd /media/last/data2/ServiceImages
   FlatTemp=FITS.read2sim('NormalizedFlatField_Temp.fits');
   TempIm = im2single(CameraObj.LastImage);
   TempIm = TempIm./FlatTemp.Im;
   cd (OrigDir);

end