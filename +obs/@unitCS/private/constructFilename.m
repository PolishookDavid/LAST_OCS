function [FileName,Path]=constructFilename(Unit,icam)
% construct a canonical filename for saving images produced by camera icam
%  (format decided 11/2021)

    CameraObj=Unit.Camera{icam};

    IP=ImagePath;

    % Is it right to use this (JD) as Time?
    IP.Time = CameraObj.classCommand('TimeStartLastImage') + 1721058.5;
    IP.CropID = 1;
    IP.CCDID = 1;

    try
        % This will run most of the times in the slaves.
        %  We rely on that connectSlave has duplicated the relevant fields
        %  of Unit.Config, so that we don't need to include them in the
        %  respective configuration files
        %  We write a fixed 01 for the mount, because so far unitCS is designed
        %   for a single one
        ProjName = sprintf('%s.%02d.01.%02d',...
                            Unit.Config.ProjName,  Unit.Config.NodeNumber, ...
                            CameraObj.classCommand('Config.CameraNumber;') );
        IP.ProjName= ProjName;
        IP.Filter = CameraObj.classCommand('Config.Filter;');
        IP.FieldID = '';  % get this from unitCS - need to discuss this
        IP.Counter =  CameraObj.classCommand('ProgressiveFrame;');
        IP.BasePath = fullfile(CameraObj.classCommand('Config.BaseDir;'),...
                               CameraObj.classCommand('Config.DataDir;'));
        IP.Type=CameraObj.ImType;
    catch
        Unit.reportError(['canonical image file name generation needs' ...
                          ' parameters which are not in config, check!'])
    end

    FileName = IP.genFile;
    Path     = IP.genPath;

