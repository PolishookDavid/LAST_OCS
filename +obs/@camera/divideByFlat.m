function ImageToDisplay=divideByFlat(CameraObj,Image)
    % Subtract dark and divide image by flat
    % Input  : - An obs.camera object
    %          - An image. If not given then will use
    %            CameraObj.LastImage.
    % Output : - Dark subtracted and flat divided image

    % TODO: with the simplest FITS.read1 the resulting images are just
    %       matrices. In future we should probably use a canonically
    %       structured image object

    if nargin<2
        Image = CameraObj.LastImage;
    end

    if isfield(CameraObj.Config,'CCDSEC')
        x1=CameraObj.Config.CCDSEC(3);
        x2=CameraObj.Config.CCDSEC(4);
        y1=CameraObj.Config.CCDSEC(1);
        y2=CameraObj.Config.CCDSEC(2);
    else
        x1=1;
        x2=size(Image,2);
        y1=1;
        y2=size(Image,1);
    end
    % convert to single
    ImageToDisplay = single(Image);

    try
        Dark = FITS.read1(fullfile(CameraObj.Config.DarkDBDir, ...
                                     [CameraObj.PhysicalId '_Dark.fits'] ));
    catch
        CameraObj.reportError('cannot read Dark reference image for camera %s',...
                                       CameraObj.PhysicalId)
    end
    
    try
        Flat = FITS.read1(fullfile(CameraObj.Config.FlatDBDir, ...
                                     [CameraObj.PhysicalId '_Flat.fits'] ));
    catch
        CameraObj.reportError('cannot read Flat reference image for camera %s',...
                                       CameraObj.PhysicalId)
    end
    
    ImageToDisplay = ImageToDisplay(x1:x2,y1:y2);
    Flat        =    Flat(x1:x2,y1:y2);
    Dark        =    Dark(x1:x2,y1:y2);

    ImageToDisplay = (ImageToDisplay - Dark)./Flat;

end
