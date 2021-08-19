function saveCurImage(UnitObj,itel)
    % Save last image to disk according the user's settings
    % Also set LastImageSaved to true, until a new image is taken
    % Intended for local as well as remote cameras in the UnitObj.
    % When called for a remote camera, the saving command is passed to
    %  the slave session hosting that camera. That is the simplest thing to
    %  do, rather than constructing the filename, and the header, all by
    %  roundtrip queries

    CameraObj=UnitObj.Camera{itel};
    
    if isa(CameraObj,'obs.remoteClass')
        SizeImIJ = CameraObj.Messenger.query(...
            sprintf('size(%s.LastImage)',CameraObj.RemoteName));
    else
        SizeImIJ = size(CameraObj.LastImage);
    end

    if prod(SizeImIJ)==0
        UnitObj.reportError(sprintf('no image taken by telescope %d to be saved',...
                            itel))
        return
    end

    % Write the fits file, in the session where the camera object lives
    if isa(CameraObj,'obs.remoteClass')
        remoteUnitName=inputname(1);
        CameraObj.Messenger.query(sprintf('%s.saveCurImage(%d)',remoteUnitName,itel));
    else
        % Construct directory name to save image in
        ProjName = sprintf('%s.%d.%s.%d', UnitObj.Config.ProjName,...
            UnitObj.Config.NodeNumber, UnitObj.Id, itel);
        JD = CameraObj.classCommand('TimeStartLastImage') + 1721058.5;
        
        % default values for fields which may be a bit too fragile to store
        %  only in config files: Filter, DataDir, BaseDir
        
        [FileName,Path]=imUtil.util.file.construct_filename('ProjName',ProjName,...
            'Date',JD,...
            'Filter',CameraObj.Config.Filter,...
            'FieldID',CameraObj.Object,...
            'Type',CameraObj.ImType,...
            'Level','raw',...
            'SubLevel','',...
            'Product','im',...
            'Version',1,...
            'FileType','fits',...
            'DataDir',CameraObj.Config.DataDir,...
            'Base',CameraObj.Config.BaseDir);
        
        CameraObj.LastImageName = FileName;
        
        % create the header locally, even from remote objects, because
        %  round-trip queries fail
        HeaderCell=constructHeader(UnitObj,itel);
        UnitObj.report(sprintf('Writing image %s to disk\n',...
            CameraObj.classCommand('LastImageName')));
        
        PWD = pwd;
        tools.os.cdmkdir(Path);  % cd and on the fly mkdir
        FITS.write(single(CameraObj.LastImage), CameraObj.LastImageName,...
                   'Header',HeaderCell,'DataType','single','Overwrite',true);
        cd(PWD);

        CameraObj.LastImageSaved = true;
    end

    % CameraObj.classCommand(['LogFile.write(' ...
    %    sprintf('Image: %s is written', CameraObj.classCommand('LastImageName') ')'])


end