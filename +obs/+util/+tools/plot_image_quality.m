function plot_image_quality(Image)
% plot image quality (FWHM) across image
% Input  : - Image matrix, A SIM object or a FITS file name.
% Example:
% obs.util.tools.plot_image_quality('LAST.1.1.3_20210308.171055.469_clear__sci_raw.n_im_1.fits')
% obs.util.tools.plot_image_quality(C.LastImage);

if isnumeric(Image)
    % Image is a matrix
    S = SIM;
    S.Im = single(Image);
elseif SIM.issim(Image)
    S = Image;
elseif ischar(Image)
    S = FITS.read2sim(Image);
else
    error('Unknown image format');
end


S = mextractor(S,'Gain',1,'Thresh',10);
F = S.Cat(:,S.Col.SN)>30 & S.Cat(:,S.Col.SN)<100 & S.Cat(:,S.Col.SN)>S.Cat(:,S.Col.SN_UNF) & S.Cat(:,S.Col.SN)>S.Cat(:,S.Col.SN_ADD_1);
[X,Y,Mn,Mnin,Mmean,MmedX2]=Util.stat.cell_stat(S.Cat(F,[S.Col.XWIN_IMAGE S.Col.YWIN_IMAGE S.Col.X2WIN_IMAGE]),[1024 1024],[1 6354 1 9576]);
[X,Y,Mn,Mnin,Mmean,MmedY2]=Util.stat.cell_stat(S.Cat(F,[S.Col.XWIN_IMAGE S.Col.YWIN_IMAGE S.Col.Y2WIN_IMAGE]),[1024 1024],[1 6354 1 9576]);
[X,Y,Mn,Mnin,Mmean,MmedXY]=Util.stat.cell_stat(S.Cat(F,[S.Col.XWIN_IMAGE S.Col.YWIN_IMAGE S.Col.XYWIN_IMAGE]),[1024 1024],[1 6354 1 9576]);
figure(1);
surface(X,Y,MmedX2.*2.35);
colorbar
title('X2');

figure(2);
surface(X,Y,MmedY2.*2.35);
colorbar
title('Y2');

figure(3);
surface(X,Y,MmedXY.*2.35);
colorbar
title('XY');

