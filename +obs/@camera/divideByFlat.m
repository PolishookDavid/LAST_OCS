function ImageToDisplay=divideByFlat(CameraObj,Image)
    % Subtract dark and divide image by flat
    % Input  : - An obs.camera object
    %          - An image. If not given then will use
    %            CameraObj.LastImage.
    % Output : - Dark subtracted and flat divided image

    if nargin<2
        Image = CameraObj.LastImage;
    end

    % convert to single
    ImageToDisplay = single(Image);

    OrigDir = pwd;

    % need to clean this part:
%             cd /media/last/data2/ServiceImages
%             cd /last02/data/serviceImages
    Dark = FITS.read2sim(fullfile(CameraObj.ConfigStruct.DarkDBDir, 'Dark.fits'));
%            S = load(fullfile(CameraObj.ConfigStruct.FlatDBDir,'Flat.mat'));  % need to update the image
%             cd(OrigDir);
%             Flat = S.Flat;
%             Flat.Im = Flat.Im./nanmedian(Flat.Im,'all');
    Flat = FITS.read2sim(fullfile(CameraObj.ConfigStruct.FlatDBDir,'Flat.fits'));  % need to update the image
    ImageToDisplay = ImageToDisplay(:,1:6387);
    Flat.Im        = Flat.Im(:,1:6387);

    ImageToDisplay = (ImageToDisplay - Dark.Im)./Flat.Im;

end
