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
    
    
    % internal gain
    I = I + 1;
    Info(I).Name = 'INTGAIN';
    Info(I).Val  = CameraObj.classCommand('Gain');

    Keys={'GAIN','DARKCUR','READNOI','SATURVAL','NONLIN'};
    % get the camera Config structure once
    CameraConfig = CameraObj.classCommand('Config');
    for i=1:numel(Keys)
        Field = Keys{i};
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
    Info(I).Name = 'SENSTEMP';
    Info(I).Val  = CameraObj.classCommand('Temperature');


    % build header from structure
    N = numel(Info);
    HeaderCell = cell(N,3);
    HeaderCell(:,1) = {Info.Name};
    HeaderCell(:,2) = {Info.Val};

    %%% OLD - REMOVE after testing
    
%     Info.NAXIS    = numel(SizeImIJ);
%     
%     Info.NAXIS1   = SizeImIJ(2);
%     Info.NAXIS2   = SizeImIJ(1);
%     Info.BITPIX   = -32;
%     Info.BZERO    = 0.0;
%     Info.BSCALE   = 1.0;
%     Info.IMTYPE   = CameraObj.classCommand('ImType');
%     Info.OBJECT   = CameraObj.classCommand('Object');
% 
%     % internal gain
%     Info.INTGAIN  = CameraObj.classCommand('Gain');
% 
%     % keys which may be or be not in Config:
%     % Gain, Read noise, Dark current
%     Keys={'GAIN','DARKCUR','READNOI'};
%     % get the camera Config structure once
%     CameraConfig = CameraObj.classCommand('Config');
%     for i=1:numel(Keys)
%         Field = Keys{i};
%         %if isfield(CameraObj.classCommand('Config'),Field)
%         if isfield(CameraConfig, Field)
%             Info.(Field)     = CameraConfig.(Field);  %CameraObj.classCommand('Config').(Field);
%         else
%             Info.(Field)     = NaN;
%         end
%     end
%     %
%     Info.BINX     = CameraObj.classCommand('Binning(1)');
%     Info.BINY     = CameraObj.classCommand('Binning(2)');
%     % 
%     Info.CamNum   = CameraObj.classCommand('CameraNumber');
%     Info.CamPos   = CameraObj.classCommand('CameraPos');
%     %Info.CamType  = class(CameraObj); % redundent
%     Info.CamModel = CameraObj.classCommand('CameraModel');
%     Info.CamName  = CameraObj.classCommand('CameraName');
% 
%     Info.JD       = 1721058.5 + CameraObj.classCommand('TimeStartLastImage');
%     %Info.ExpTime  = CameraObj.classCommand('LastImageExpTime');
%     Info.ExpTime  = CameraObj.classCommand('ExpTime');
%     
%     % added by Enrico
%     Info.SENSTEMP = CameraObj.classCommand('Temperature');

    % eventual additional comment fields written independently in
    %  ConfigHeader:
    % ConfigHeader may contain additional constant keyword/values taht will
    % be written to all headers.
%    CommentsDB = CameraObj.classCommand('ConfigHeader');

%     FN  = fieldnames(Info);
%     Nfn = numel(FN);
%     if ~isempty(CommentsDB)
%         CommentFN = fieldnames(CommentsDB);
%     end
%     HeaderCell = cell(Nfn,3);
%     for Ifn=1:Nfn
%         HeaderCell{Ifn,1} = upper(FN{Ifn});
%         HeaderCell{Ifn,2} = Info.(FN{Ifn});
%         if ~isempty(CommentsDB)
%             % get comment
%             Ind = find(strcmpi(FN{Ifn},CommentFN));
%             if ~isempty(Ind)
%                 HeaderCell{Ifn,3} = CommentsDB.(CommentFN{Ind});
%             end
%         end
%     end

end