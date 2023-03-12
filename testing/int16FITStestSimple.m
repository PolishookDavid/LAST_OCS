% test image with vertical gradient and central white square
im=kron(uint16(0:64:65535)',ones(1,1000,'uint16'));
im(size(im,1)/2+(-20:20),size(im,2)/2+(-20:20))=uint16(65535);
imagesc(im); colorbar

% write simple FITS with automatic casting and BZERO
%  (Astropack branch fits-u16)
FITS.writeSimpleFITS(im, 'gradsquare.fits');

result=FITS.read1('gradsquare.fits');

% this should be 0 if all was ok
numel(find(result-im))

import matlab.io.*
fptr = fits.openFile('gradsquare.fits');
data = fits.readImg(fptr);
fits.closeFile(fptr);

% also this should be 0 if all was ok
numel(find(data-im))
