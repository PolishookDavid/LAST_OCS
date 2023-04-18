function [FileName,Path]=constructFilename(Unit,icam)
% construct a canonical filename for saving images produced by camera icam
%  (format decided 11/2021)

% compare with obs.camera.constructFilename (private method)

    IP=Unit.Camera{icam}.cameraImageObject;

    try
        camnum=CameraObj.classCommand('Config.CameraNumber;');
        ProjName = sprintf('%s.%02d.%02d.%02d',...
                            Unit.Config.ProjName,  Unit.Config.NodeNumber, ...
                            Unit.MountNumber,camnum);
    catch
        Unit.reportError(['canonical image file name generation needs' ...
                          ' parameters which are not in config, check!'])
    end

    IP.ProjName= ProjName;
    FileName = IP.genFile;
    Path     = IP.genPath;
