function dispim(CamObj)
% Example: devel.dispim(C)

F=FITS.read2sim('/home/last/Downloads/Flat.fits');

%F.Im = F.Im(1:9568,1:6386);

Image = single(CamObj.LastImage)./single(F.Im);

Q = quantile(Image(:),[0.05 0.95]);


imagesc(Image,[Q(1), Q(2)]);
axis equal

