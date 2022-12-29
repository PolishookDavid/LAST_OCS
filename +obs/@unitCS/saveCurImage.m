function saveCurImage(UnitObj,itel,Path)
% Save the last images to disk according the user's settings (unit version)
% Also set LastImageSaved to true, until a new image is taken
% Inputs:
%    - indices of the cameras whose images have to be saved
%    - optional path, if it needs to be different than the default for
%                     science images
%
% Intended for local as well as remote cameras in the UnitObj.
% When called for a remote camera, the saving command is passed to
%  the slave session hosting that camera. That is the simplest thing to
%  do, rather than constructing the filename, and the header, all by
%  roundtrip queries. The image data anyway resides in the slave.

    if ~exist('itel','var')
        itel=[];
    end
    if isempty(itel)
        itel=1:numel(UnitObj.Camera);
    end

    for icam=itel
        CameraObj=UnitObj.Camera{icam};

        if isa(CameraObj,'obs.remoteClass')
            SizeImIJ = CameraObj.Messenger.query(...
                sprintf('size(%s.LastImage)',CameraObj.RemoteName));
        else
            SizeImIJ = size(CameraObj.LastImage);
        end

        if prod(SizeImIJ)==0
            UnitObj.reportError('no image taken by telescope %d to be saved',...
                icam)
            return
        end

        % Write the fits file, in the session where the camera object lives
        if isa(CameraObj,'obs.remoteClass')
            remoteUnitName=strtok(CameraObj.RemoteName,'.');
            if exist('Path','var')
                CameraObj.Messenger.query(sprintf('%s.saveCurImage(%d,''%s'')',...
                                                 remoteUnitName,icam,Path));
            else
                CameraObj.Messenger.query(sprintf('%s.saveCurImage(%d)',...
                                                  remoteUnitName,icam));
            end
        else
            % this runs where CameraObj lives, we don't need classCommand's

            % Construct directory and file name to save image
            %  (format decided 11/2021)
            [FileName,DefaultPath] = constructFilename(UnitObj,icam);
            
            if ~exist('Path','var')
                Path=DefaultPath;
            end
            
            % override Path, if NewImagePath is available
            if ~isempty(CameraObj.Config.DataDir)
                IP_Parts = split(FileName, '_');
                Path = [CameraObj.Config.BaseDir, filesep, IP_Parts{1}, filesep, CameraObj.Config.DataDir];
            end

            FullPath = fullfile(Path,FileName);

            HeaderCell=constructHeader(UnitObj,icam);
            UnitObj.report('Writing image %s to disk\n',FullPath);

            % prepend FILENAME to header
            HeaderCell=[{'FILENAME',FullPath,''};HeaderCell];

            PWD = pwd;
            try
                tools.os.cdmkdir(Path);  % cd and on the fly mkdir
                FITS.write(single(CameraObj.LastImage), FullPath,...
                    'Header',HeaderCell,'DataType','single','Overwrite',true);
                
                CameraObj.LastImageSaved = true;
                CameraObj.LastImageName = FullPath;
            catch
                CameraObj.reportError('saving image in %s failed',Path)
            end
            cd(PWD);
        end
    end

    % CameraObj.classCommand(['LogFile.write(' ...
    %    sprintf('Image: %s is written', CameraObj.classCommand('LastImageName') ')'])

end