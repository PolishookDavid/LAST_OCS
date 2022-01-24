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
    
%     IP = ImagePath;
%     %IP.ProjName = sprintf('%s.%02d.%02d')
%     IP.Time     = JD;
%     IP.Filter   = CameraObj.Config.Filter;
%     IP.FieldID  = CameraObj.Object;
%     IP.Counter  = 1;
%     IP.CCDID    = 1;
%     IP.CropID   = 0;
%     IP.Type     = CameraObj.ImType;
%     IP.Level    = 'raw';
%     IP.PathLevel= [];
%     IP.SubLevel = '';
%     IP.Product  = 'Image';
%     IP.Version  = '1';
%     IP.FileType = 'fits';
%     
%     
%     [FileName,DefaultPath]=imUtil.util.file.construct_filename('Date',JD,...
%         'Filter',CameraObj.Config.Filter,...
%         'FieldID',CameraObj.Object,...
%         'Type',CameraObj.ImType,...
%         'Level','raw',...
%         'SubLevel','',...
%         'Product','im',...
%         'Version',1,...
%         'FileType','fits',...
%         'DataDir',CameraObj.Config.DataDir,...
%         'Base',CameraObj.Config.BaseDir);
    
    if ~exist('Path','var')
        Path=DefaultPath;
    end

    % create the header locally, even from remote objects, because
    %  round-trip queries fail
    HeaderCell=CameraObj.imageHeader;
    CameraObj.report('Writing image %s to disk\n',...
                              CameraObj.LastImageName);

    PWD = pwd;
    try
        tools.os.cdmkdir(Path);  % cd and on the fly mkdir
        FITS.write(single(CameraObj.LastImage), CameraObj.LastImageName,...
            'Header',HeaderCell,'DataType','single','Overwrite',true);      
        CameraObj.LastImageName = fullfile(Path,FileName);
        CameraObj.LastImageSaved = true;
    catch
        CameraObj.reportError('saving image in %s failed',Path)
    end
    cd(PWD);

    % CameraObj.classCommand(['LogFile.write(' ...
    %    sprintf('Image: %s is written', CameraObj.LastImageName') ')'])


end