function [HeaderCell,Info]=imageHeader(CameraObj)
% construct the image header based on all the information pertinent to the
%  camera alone
% The method would be private, but unitCS needs to call it when
%  constructing a full header, hence it cannot
    if isa(CameraObj,'obs.remoteClass')
        SizeImIJ = CameraObj.Messenger.query(...
            sprintf('size(%s.LastImage)',CameraObj.RemoteName));
    else
        SizeImIJ = size(CameraObj.LastImage);
    end

    % Image related information
    %    12345678
    Info.NAXIS    = numel(SizeImIJ);
    Info.NAXIS1   = SizeImIJ(2);
    Info.NAXIS2   = SizeImIJ(1);
    Info.BITPIX   = -32;
    Info.BZERO    = 0.0;
    Info.BSCALE   = 1.0;
    Info.IMTYPE   = CameraObj.classCommand('ImType');
    Info.OBJECT   = CameraObj.classCommand('Object');

    % internal gain
    Info.INTGAIN  = CameraObj.classCommand('Gain');

    % keys which may be or be not in Config:
    % Gain, Read noise, Dark current
    Keys={'GAIN','DARKCUR','READNOI'};
    for i=1:numel(Keys)
        Field = Keys{i};
        if isfield(CameraObj.classCommand('Config'),Field)
            Info.(Field)     = CameraObj.classCommand('Config').(Field);
        else
            Info.(Field)     = NaN;
        end
    end
    %
    Info.BINX     = CameraObj.classCommand('Binning(1)');
    Info.BINY     = CameraObj.classCommand('Binning(2)');
    % 
    Info.CamNum   = CameraObj.classCommand('CameraNumber');
    Info.CamPos   = CameraObj.classCommand('CameraPos');
    Info.CamType  = class(CameraObj);
    Info.CamModel = CameraObj.classCommand('CameraModel');
    Info.CamName  = CameraObj.classCommand('CameraName');

    Info.JD       = 1721058.5 + CameraObj.classCommand('TimeStartLastImage');
    %Info.ExpTime  = CameraObj.classCommand('LastImageExpTime');
    Info.ExpTime  = CameraObj.classCommand('ExpTime');
    
    % added by Enrico
    Info.SENSTEMP = CameraObj.classCommand('Temperature');

    % eventual additional comment fields written independently in
    %  ConfigHeader (purpose and mechanics frankly unclear to me)
    CommentsDB = CameraObj.classCommand('ConfigHeader');

    FN  = fieldnames(Info);
    Nfn = numel(FN);
    if ~isempty(CommentsDB)
        CommentFN = fieldnames(CommentsDB);
    end
    HeaderCell = cell(Nfn,3);
    for Ifn=1:Nfn
        HeaderCell{Ifn,1} = upper(FN{Ifn});
        HeaderCell{Ifn,2} = Info.(FN{Ifn});
        if ~isempty(CommentsDB)
            % get comment
            Ind = find(strcmpi(FN{Ifn},CommentFN));
            if ~isempty(Ind)
                HeaderCell{Ifn,3} = CommentsDB.(CommentFN{Ind});
            end
        end
    end
