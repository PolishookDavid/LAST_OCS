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
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'NAXIS1';
    Info(I).Val  = SizeImIJ(2);
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'NAXIS2';
    Info(I).Val  = SizeImIJ(1);
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'BITPIX';
    Info(I).Val  = -32;
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'BZERO';
    Info(I).Val  = 0.0;
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'BSCALE';
    Info(I).Val  = 1.0;
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'IMTYPE';
    Info(I).Val  = CameraObj.classCommand('ImType');
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'OBJECT';
    Info(I).Val  = CameraObj.classCommand('Object');
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'GIT_CAMR';
    Info(I).Val = CameraObj.classCommand('GitVersion');
    Info(I).Descr = 'git version of the camera driver software';
        
    I = I + 1;
    Info(I).Name = 'EXPMODE';
    switch CameraObj.classCommand('StreamMode')
        case 0
           Info(I).Val  = 'SINGLE';
        case 1
           Info(I).Val  = 'VIDEO';
        otherwise
           Info(I).Val  = 'UNKNOWN';
    end
    Info(I).Descr = 'continuous exposure mode of the camera';
    
    I = I + 1;
    Info(I).Name = 'Counter';
    Info(I).Val  = CameraObj.classCommand('ProgressiveFrame');
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'EXPTIME';
    Info(I).Val  = CameraObj.classCommand('ExpTime');
    Info(I).Descr = '';
    
    I = I + 1;
    Info(I).Name = 'FILTER';
    Info(I).Val  = CameraObj.classCommand('Filter');
    Info(I).Descr = '';
        
    I = I + 1;
    Info(I).Name = 'JD';
    Info(I).Val  = 1721058.5 + CameraObj.classCommand('TimeStartLastImage');
    Info(I).Descr = '';

    % Keys={'GAIN','DARKCUR','READNOI','SATURVAL','NONLIN'};
    % Read additional fixed keys from camera Config.FITSHeader
    ExtraKeys = CameraObj.classCommand('Config.FITSHeader');
    for i=1:numel(ExtraKeys)
        I= I + 1;
        Info(I).Name = ExtraKeys{i}{1};
        Info(I).Val  = ExtraKeys{i}{2};
    end

    I = I + 1;
    Info(I).Name = 'BINX';
    Info(I).Val  = CameraObj.classCommand('Binning(1)');
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'BINY';
    Info(I).Val  = CameraObj.classCommand('Binning(2)');
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'CAMNUM';
    Info(I).Val  = CameraObj.classCommand('CameraNumber');
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'CAMPOS';
    Info(I).Val  = CameraObj.classCommand('CameraPos');
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'CAMNAME';
    Info(I).Val  = CameraObj.classCommand('CameraName');
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'CAMTEMP';
    Info(I).Val  = CameraObj.classCommand('Temperature');
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'CAMCOOL';
    Info(I).Val  = CameraObj.classCommand('CoolingPower');
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'CAMMODE';
     % matlab.io.fits.writeKey doesn't handle uint32
    Info(I).Val  = int32(CameraObj.classCommand('ReadMode'));
    Info(I).Descr = 'Reading mode of the camera';

    I = I + 1;
    Info(I).Name = 'CAMGAIN';
    Info(I).Val  = CameraObj.classCommand('Gain');
    Info(I).Descr = '';

    I = I + 1;
    Info(I).Name = 'CAMOFFS';
    Info(I).Val  = CameraObj.classCommand('Offset');
    Info(I).Descr = '';

    % build header from structure
    N = numel(Info);
    HeaderCell = cell(N,3);
    HeaderCell(:,1) = {Info.Name};
    HeaderCell(:,2) = {Info.Val};
    HeaderCell(:,3) = {Info.Descr};

end