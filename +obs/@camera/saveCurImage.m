function saveCurImage(CameraObj)
    % Save last image to disk according the user's settings
    % Also set LastImageSaved to true, until a new image is arrive


    % Construct directory name to save image in
    ProjName = sprintf('%s.%d.%02d.%d',CameraObj.ConfigStruct.ProjectName,...
                                       CameraObj.ConfigStruct.NodeNumber,...
                                       CameraObj.ConfigStruct.MountNumber,...
                                       CameraObj.ConfigStruct.CameraNumber);
    JD        = CameraObj.Handle.TimeStartLastImage + 1721058.5;   

    [FileName,Path]=imUtil.util.file.construct_filename('ProjName',ProjName,...
                                                        'Date',JD,...
                                                        'Filter',CameraObj.ConfigStruct.Filter,...
                                                        'FieldID',CameraObj.Object,...
                                                        'Type',CameraObj.ImType,...
                                                        'Level','raw',...
                                                        'SubLevel','',...
                                                        'Product','im',...
                                                        'Version',1,...
                                                        'FileType','fits',...
                                                        'DataDir',CameraObj.ConfigStruct.DataDir,...
                                                        'Base',CameraObj.ConfigStruct.BaseDir);
    CameraObj.LastImageName = FileName;

    %DirName = obs.util.config.constructDirName('raw');
    %PWD = pwd;

    %cd(DirName);

    [HeaderCell,Info]=constructHeader(CameraObj);  % get header

    % This part need to be cleaned
    %ConfigNode  = obs.util.config.read_config_file('/home/last/config/config.node.txt');
    %ConfigMount = obs.util.config.read_config_file('/home/last/config/config.mount.txt');

    % Construct image name   
%             if isempty(CameraObj.ConfigMount)
%                 NodeNumber  = 0;
%                 MountNumber = 0;
%                 CameraObj.LogFile.writeLog('ConfigMount is empty while saveCurImage');
%             else
%                 if Util.struct.isfield_notempty(CameraObj.ConfigMount,'NodeNumber')
%                     NodeNumber  = CameraObj.ConfigMount.NodeNumber;
%                 else
%                     NodeNumber  = 0;
%                 end
%                 if Util.struct.isfield_notempty(CameraObj.ConfigMount,'MountNumber')
%                     MountNumber = CameraObj.ConfigMount.MountNumber;
%                 else
%                     MountNumber = 0;
%                 end
%             end


    %ProjectName      = sprintf('LAST.%d.%02d.%d',NodeNumber,MountNumber,CameraObj.CameraNumber);
    %ImageDate        = datestr(CameraObj.Handle.TimeStartLastImage,'yyyymmdd.HHMMSS.FFF');
    %ObservatoryNode  = num2str(ConfigNode.ObservatoryNode);
    %MountGeoName     = num2str(ConfigMount.MountGeoName);

%             FieldID          = CameraObj.Object;
%             ImLevel          = 'raw';
%             ImSubLevel       = 'n';
%             ImProduct        = 'im';
%             ImVersion        = '1';
% 
%             % Image name legend:    LAST.Node.mount.camera_YYYYMMDD.HHMMSS.FFF_Filter_CCDnum_ImType.fits
%             % Image name example:   LAST.1.1.e_20200603.063549.030_clear_0_science.fits
%             %CameraObj.LastImageName = obs.util.config.constructImageName(ProjectName, ObservatoryNode, MountNumber, CameraObj.CameraNumber, ImageDate, CameraObj.Filter, FieldID, CameraObj.ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, CameraObj.ImageFormat);
%             CameraObj.LastImageName = obs.util.config.constructImageName(CameraObj.ConfigStruct.ProjectName,...
%                                                                          CameraObj.ConfigStruct.NodeNumber,...
%                                                                          CameraObj.ConfigStruct.MountNumber,...
%                                                                          CameraObj.CameraNumber,...
%                                                                          ImageDate, CameraObj.Filter, FieldID, CameraObj.ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, CameraObj.ImageFormat);
%             

    % Construct header
    % OLD: Header = CameraObj.updateHeader;

    if CameraObj.Verbose
        fprintf('Writing image name %s to disk\n',CameraObj.LastImageName);
    end

    % Write fits
    PWD = pwd;
    Util.OS.cdmkdir(Path);  % cd and on the fly mkdir
    FITS.write(single(CameraObj.Handle.LastImage), CameraObj.LastImageName,'Header',HeaderCell,'DataType','single');
    cd(PWD);


    CameraObj.LogFile.writeLog(sprintf('Image: %s is written', CameraObj.LastImageName))


    CameraObj.LastImageSaved = true;

end
