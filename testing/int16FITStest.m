im=kron(uint16(0:64:65535)',ones(1,1000,'uint16'));
im(size(im,1)/2+(-20:20),size(im,2)/2+(-20:20))=uint16(65535);
imagesc(im); colorbar

Info=struct();
I = 0;

I = I + 1;
Info(I).Name = 'SIMPLE';
Info(I).Val  = true;
% BITPIX needs to be the second, otherwise fitsiolib (FITS.read1) complains:
%  CFITSIO library error (222): second keyword not BITPIX
I = I + 1;
Info(I).Name = 'BITPIX';
Info(I).Val  = 16;
% both ds9 and FITS.read1 read the same also with -16
I = I + 1;
Info(I).Name = 'NAXIS';
Info(I).Val  = numel(size(im));
I = I + 1;
Info(I).Name = 'NAXIS1';
Info(I).Val  = size(im,2);
I = I + 1;
Info(I).Name = 'NAXIS2';
Info(I).Val  = size(im,1);

I = I + 1;
Info(I).Name = 'BZERO';
Info(I).Val  = 32768;
I = I + 1;
Info(I).Name = 'BSCALE';
Info(I).Val  = 1.0;

% build header from structure
N = numel(Info);
HeaderCell = cell(N,3);
HeaderCell(:,1) = {Info.Name};
HeaderCell(:,2) = {Info.Val};
    
% image to signed int16
im16=int16(int32(im)-int32(32768));

FITS.writeSimpleFITS(im16, 'gradsquare.fits', 'Header', HeaderCell);

result=FITS.read1('gradsquare.fits');

% this should be 0 if all was ok
numel(find(result-im))

import matlab.io.*
fptr = fits.openFile('gradsquare.fits');
data = fits.readImg(fptr);
fits.closeFile(fptr);

% also this should be 0 if all was ok
numel(find(data-im))
