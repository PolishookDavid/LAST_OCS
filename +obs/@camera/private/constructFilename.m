function [FileName,Path]=constructFilename(CameraObj)
% construct a canonical filename for saving images produced by camera icam
%  (format decided 11/2021)

% compare with obs.unitCS.constructFilename (private method)

    IP=CameraObj.cameraImageObject;

    camnum=CameraObj.classCommand('Config.CameraNumber;');
    ProjName = sprintf('%02d',camnum);

    IP.ProjName= ProjName;
    FileName = IP.genFile;
    Path     = IP.genPath;
