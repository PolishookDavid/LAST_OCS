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
%  roundtrip queries

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
            % Construct directory name to save image in

% old filename generation
            ProjName = sprintf('%s.%d.%s.%d', UnitObj.Config.ProjName,...
                UnitObj.Config.NodeNumber, UnitObj.Id, icam);
            JD = CameraObj.classCommand('TimeStartLastImage') + 1721058.5;
            
            % default values for fields which may be a bit too fragile to store
            %  only in config files: Filter, DataDir, BaseDir (of Unit
            %  and Camera -- see the private method unitCS.constructFilename)
            
            [FileName,DefaultPath]=imUtil.util.file.construct_filename('ProjName',ProjName,...
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

% CHECK -this should be used instead, if it works
%            [FileName,DefaultPath]=constructFilename(Unit,icam);

            if ~exist('Path','var')
                Path=DefaultPath;
            end
            
            CameraObj.LastImageName = fullfile(Path,FileName);
            
            % create the header locally, even from remote objects, because
            %  round-trip queries fail
            HeaderCell=constructHeader(UnitObj,icam);
            UnitObj.report('Writing image %s to disk\n',...
                           CameraObj.classCommand('LastImageName'));
            
            PWD = pwd;
            tools.os.cdmkdir(Path);  % cd and on the fly mkdir
            FITS.write(single(CameraObj.LastImage), CameraObj.LastImageName,...
                'Header',HeaderCell,'DataType','single','Overwrite',true);
            cd(PWD);
            
            CameraObj.LastImageSaved = true;
        end
    end

    % CameraObj.classCommand(['LogFile.write(' ...
    %    sprintf('Image: %s is written', CameraObj.classCommand('LastImageName') ')'])


end