function [FileName,Path]=constructFilename(CameraObj)
% construct a canonical filename for saving images produced by camera icam
%  (format decided 11/2021)
% Trimmed down from obs.unitCS.constructFilename (private method)

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
        ProjName = sprintf('%02d',CameraObj.classCommand('Config.CameraNumber;') );
        IP.ProjName= ProjName;
        IP.Filter = CameraObj.classCommand('Config.Filter;');
        IP.FieldID = CameraObj.classCommand('Object');
        IP.Counter =  CameraObj.classCommand('ProgressiveFrame;');
        IP.BasePath = fullfile(CameraObj.classCommand('Config.BaseDir;'),...
                               CameraObj.classCommand('Config.DataDir;'));
        IP.Type=CameraObj.ImType;
    catch
        CameraObj.reportError(['canonical image file name generation needs' ...
                          ' parameters which are not in config, check!'])
    end

    FileName = IP.genFile;
    Path     = IP.genPath;
