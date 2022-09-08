function [HeaderCell,Info]=imageHeader(CameraObj)
    % construct the image header based on all the information pertinent to the
    %  camera alone - THIS FUNCTION IS USED BY THE CAMERA OBJECT.
    % For HEADERS written by the UnitCS, see UnitCS private methods. 
    % The method would be private, but unitCS needs to call it when
    %  constructing a full header, hence it cannot
    
    % get image size
    if isa(CameraObj,'obs.remoteClass')
        SizeImIJ = CameraObj.Messenger.query(...
            sprintf('size(%s.LastImage)',CameraObj.RemoteName));
    else
        SizeImIJ = size(CameraObj.LastImage);
    end
    
    % Image related information
    %    12345678
    I = 0;    
    
    I = I + 1;
    Info(I).Name = 'NAXIS';
    Info(I).Val  = numel(SizeImIJ);
    
    I = I + 1;
    Info(I).Name = 'NAXIS1';
    Info(I).Val  = SizeImIJ(2);
    
    I = I + 1;
    Info(I).Name = 'NAXIS2';
    Info(I).Val  = SizeImIJ(1);
    
    I = I + 1;
    Info(I).Name = 'BITPIX';
    Info(I).Val  = -32;
    
    I = I + 1;
    Info(I).Name = 'BZERO';
    Info(I).Val  = 0.0;
    
    I = I + 1;
    Info(I).Name = 'BSCALE';
    Info(I).Val  = 1.0;

    I = I + 1;
    Info(I).Name = 'IMTYPE';
    Info(I).Val  = CameraObj.classCommand('ImType');
    
    I = I + 1;
    Info(I).Name = 'OBJECT';
    Info(I).Val  = CameraObj.classCommand('Object');
    
    I = I + 1;
    Info(I).Name = 'EXPTIME';
    Info(I).Val  = CameraObj.classCommand('ExpTime');
    
    I = I + 1;
    Info(I).Name = 'FILTER';
    Info(I).Val  = CameraObj.classCommand('Filter');
        
    I = I + 1;
    Info(I).Name = 'JD';
    Info(I).Val  = 1721058.5 + CameraObj.classCommand('TimeStartLastImage');

    Keys={'GAIN','DARKCUR','READNOI','SATURVAL','NONLIN'};
    % get the camera Config structure once
    CameraConfig = CameraObj.classCommand('Config');
    for i=1:numel(Keys)
        Field = Keys{i};
        I= I + 1;
        Info(I).Name = Keys{i};
        %if isfield(CameraObj.classCommand('Config'),Field)
        if isfield(CameraConfig, Field)
            Info(I).Val  = CameraConfig.(Field);  %CameraObj.classCommand('Config').(Field);
        else
            Info(I).Val  = NaN;
        end
    end

    I = I + 1;
    Info(I).Name = 'BINX';
    Info(I).Val  = CameraObj.classCommand('Binning(1)');

    I = I + 1;
    Info(I).Name = 'BINY';
    Info(I).Val  = CameraObj.classCommand('Binning(2)');

    I = I + 1;
    Info(I).Name = 'CAMNUM';
    Info(I).Val  = CameraObj.classCommand('CameraNumber');

    I = I + 1;
    Info(I).Name = 'CAMPOS';
    Info(I).Val  = CameraObj.classCommand('CameraPos');

    I = I + 1;
    Info(I).Name = 'CAMNAME';
    Info(I).Val  = CameraObj.classCommand('CameraName');

    I = I + 1;
    Info(I).Name = 'CAMTEMP';
    Info(I).Val  = CameraObj.classCommand('Temperature');

    I = I + 1;
    Info(I).Name = 'CAMCOOL';
    Info(I).Val  = CameraObj.classCommand('CoolingPower');

    I = I + 1;
    Info(I).Name = 'CAMMODE';
    Info(I).Val  = CameraObj.classCommand('ReadMode');

    I = I + 1;
    Info(I).Name = 'CAMGAIN';
    Info(I).Val  = CameraObj.classCommand('Gain');

    I = I + 1;
    Info(I).Name = 'CAMOFFS';
    Info(I).Val  = CameraObj.classCommand('Offset');

    % build header from structure
    N = numel(Info);
    HeaderCell = cell(N,3);
    HeaderCell(:,1) = {Info.Name};
    HeaderCell(:,2) = {Info.Val};

end