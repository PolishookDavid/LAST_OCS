function saveCurImage(CameraObj,Path)
    % Save the last acquired image to disk (camera only version)
    % Also set LastImageSaved to true, until a new image is taken
    % Input: the path where to save the image. If omitted, the canonical one
    %  is used
    %
    % cfr. unitCS.saveCurImage. UnitCS calls its own saveCurImage automatically
    %  upon notification of new images, whereas this method is intended for
    %  programmatic use, for example for saving darks or user images
    
    if isempty(CameraObj.LastImage)
        CameraObj.reportError('no image taken by camera %s to be saved',...
                              CameraObj.Id)
        return
    end
    
    % Write the fits file, in the session where the camera object lives
    % Construct directory name to save image in
        
    % Default Path can be overriden if provided
    if ~exist('Path','var')
        [FileName,Path] = CameraObj.constructFilename;
    else
        FileName = CameraObj.constructFilename;
    end

    % create the header locally, even from remote objects, because
    %  round-trip queries fail
    HeaderCell=CameraObj.imageHeader;
    CameraObj.LastImageName = fullfile(Path,FileName);
    CameraObj.report('Writing image %s to disk\n',...
                              CameraObj.LastImageName);

    PWD = pwd;
    try
        tools.os.cdmkdir(Path);  % cd and on the fly mkdir
        FITS.writeSimpleFITS(CameraObj.LastImage, FileName,...
                                     'Header',HeaderCell);
        CameraObj.LastImageSaved = true;
    catch
        CameraObj.reportError('saving image in %s failed',Path)
    end
    cd(PWD);

    % CameraObj.classCommand(['LogFile.write(' ...
    %    sprintf('Image: %s is written', CameraObj.LastImageName') ')'])


end