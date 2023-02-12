function saveCurImage(CameraObj,Path)
    % Save the last acquired image to disk (camera only version)
    % Also set LastImageSaved to true, until a new image is taken
    % Input: the path where to save the image. If omitted, the default one
    %  constructed from .Config.BaseDir and .Config.DataDir is used
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
    JD = CameraObj.TimeStartLastImage + 1721058.5;
    
    % default values for fields which may be a bit too fragile to store
    %  only in config files: Filter, DataDir, BaseDir
    
% DefaultPath not constructed here like it is in unitCS.saveCurImage.
%  Let it error if Path is not provided
     if ~exist('Path','var')
         error('Path must be provided')
     end

    FileName = constructFilename(CameraObj);

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