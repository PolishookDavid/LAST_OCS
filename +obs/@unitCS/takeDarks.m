function takeDarks(Unit,Cameras,ExpTime,Nimages,varargin)
% Take a sequence of dark images
%
% Same as takeExposure

    if ~exist('Cameras','var') || isempty(Cameras)
        Cameras=1:numel(Unit.Camera);
    end
    
    if ~exist('Nimages','var') || isempty(Nimages)
        Nimages = 10;
    end
    
    if ~exist('ExpTime','var') || isempty(ExpTime)
        ExpTime=zeros(size(Cameras));
        for i=1:numel(Cameras)
            ExpTime(i) = Unit.Camera{Cameras(i)}.classCommand('ExpTime');
        end
    else
        if numel(ExpTime)==1
            ExpTime=repmat(ExpTime,size(Cameras));
        end 
        for i=1:numel(Cameras)
            Unit.Camera{Cameras(i)}.classCommand('ExpTime=%f;',ExpTime(i));
        end
    end
    
    InPar = inputParser;
    addOptional(InPar,'WaitFinish',false);
    addOptional(InPar,'ImType','dark');
    addOptional(InPar,'Object','');
    addOptional(InPar,'MinExpTimeForSave',5); % [s] Minimum ExpTime below which SaveOnDisk is disabled
    parse(InPar,varargin{:});
    InPar = InPar.Results;

    if ~isempty(InPar.Object)
        % update ImType
        Unit.Camera{Cameras}.classCommand(['Object=' InPar.Object ';']);
    end
    
    if Nimages>1 && min(ExpTime) < InPar.MinExpTimeForSave
        Unit.reportError([sprintf('If Nimages>1 then ExpTime must be above %g s',...
                          InPar.MinExpTimeForSave),...
                        '; camera.SaveOnDisk will be turned off for all cameras involved']);
        % keep the previous SaveOnDisk status
        saving=false(size(Cameras));
        for i=numel(Cameras)
            saving(i)=Unit.Camera{Cameras(i)}.classCommand('SaveOnDisk;');
            Unit.Camera{Cameras(i)}.classCommand('SaveOnDisk=false;');
            % however, this seems to have had no effect inside
            % unitCS.treatNewImage. Why? some issue of snapshotting the
            % object at the moment of creation of the listener, or
            % something intricate else?
        end
    end

    % end argument parsing
    
    % wait before starting, if asked to
    if InPar.WaitFinish
        Unit.Mount.classCommand('waitFinish;');
        % wait sequentially for each camera, because camera.waitFinish
        %  has been implemented scalarly. No big deal however, because
        %  at the end we'll proceed only when the last of the busy cameras
        %  is free, no matter the order of checking
        % NOTE: THIS IS PROBLEMATIC WITH REMOTE OBJECTS
        for i=Cameras
            Unit.Focuser{i}.classCommand('waitFinish;');
            Unit.Camera{i}.classCommand('waitFinish;');
        end
    end

    % start acquisition on each of the local cameras, using nonblocking
    %  methods, and of the remote ones, using blind sends for maximum speed.
    %  This difference prevents the use of .classCommand() for both
    for i=Cameras
        CamStatus=Unit.Camera{i}.classCommand('CamStatus;');
        if strcmp(CamStatus,'idle')
            if isa(Unit.Camera{i},'obs.remoteClass')
                remotename=Unit.Camera{i}.RemoteName;
                if Nimages>1
                    Unit.Camera{i}.Messenger.send(sprintf('%s.takeDarks(''Ndark'',%d,''ExpTime'',%d)',remotename,Nimages,ExpTime));
                end
            else
                if Nimages>1
                    Unit.Camera{i}.takeDarks('Ndark',Nimages,'ExpTime',ExpTime);
                end
            end
            % otherwise it would be just:
            %         if Nimages>1
            %             Unit.Camera{i}.classCommand('takeLive(%d)',Nimages);
            %         else
            %             Unit.Camera{i}.classCommand('takeExposure');
            %         end
        else
            Unit.reportError('Camera %d status is "%s", cannot take exposures!',...
                             i,CamStatus)
        end
    end
    
    % restore the previous SaveOnDisk status if needed
     if Nimages>1 && min(ExpTime) < InPar.MinExpTimeForSave
        for i=numel(Cameras)
            Unit.Camera{Cameras(i)}.classCommand('SaveOnDisk=%d;',saving(i));
        end
    end
   

end
