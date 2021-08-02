function takeExposure(Unit,Cameras,ExpTime,Nimages,varargin)
    % Take one or many exposures from one or many local or remote cameras
    %  if a camera is busy, wait
    % Package: +obs.@unitCS
    % Input  : - a vector of camera indices [all cameras if omitted]
    %          - Exposure time [s]. If provided this will override
    %            the Camera.ExpTime, and the Camera.ExpTime
    %            will be set to this value.
    %          - Number of images to obtain. Default is 1.
    %          * ...,key,val,...
    %            'WaitFinish' - default is true.
    %            'ImType' - default is ''.
    %            'Object' - default is ''.
    % Output : - Sucess flag.

    % TAKE CARE: Unit.Camera{1}.classCommand('takeExposure') fails for a
    %   remote camera if Unit.Camera{1}.SaveOnDisk=true, because of non
    %   nestable callbacks. Find a way of dispatching
    %     Unit.takeExposure(remotecameras,parameters)
    %
    % Also, Unit.Camera{1}.classCommand('waitFinish') may timeout
    %  because of no reply, if the messenger timeout is shorter than
    %  ExpTime
    
    % argument parsing
    if ~exist('Cameras','var') || isempty(Cameras)
        Cameras=1:numel(Unit.Camera);
    end
    
    if ~exist('Nimages','var') || isempty(Nimages)
        Nimages = 1;
    end
    
    if ~exist('ExpTime','var') || isempty(ExpTime)
        ExpTime=zeros(size(Cameras));
        for i=1:numel(Cameras)
            ExpTime(i) = Unit.Camera{Cameras(i)}.classCommand('ExpTime');
        end
    end
    
    InPar = inputParser;
    addOptional(InPar,'WaitFinish',false);
    addOptional(InPar,'ImType','');
    addOptional(InPar,'Object','');
    parse(InPar,varargin{:});
    InPar = InPar.Results;

    if ~isempty(InPar.ImType)
        % update ImType
        Unit.Camera{Cameras}.classCommand(['ImType=' InPar.ImType ';']);
    end
    if ~isempty(InPar.Object)
        % update ImType
        Unit.Camera{Cameras}.classCommand(['Object=' InPar.Object ';']);
    end

    MinExpTimeForSave = 5;  % [s] Minimum ExpTime below SaveDuringNextExp is disabled

    if Nimages>1 && ExpTime<MinExpTimeForSave
        error('If Nimages>1 then ExpTime must be above %f s',MinExpTimeForSave);
    end

    % end argument parsing
    
    % remote cameras, WaitFinish=true or Nimages>1: temporarily increase
    % the messenger timeout
    timeout=zeros(Cameras);
    if InPar.WaitFinish
        for i=Cameras
            if isa(Unit.Camera{i},'obs.remoteClass')
                % perhaps increase temporarily the messenger timeout
                timeout(i) = Unit.Camera{1}.Messenger.StreamResource.Timeout;
                Unit.Camera{1}.Messenger.StreamResource.Timeout=...
                    max(timeout(i),Unit.Camera{1}.classCommand('ExpTime'));
            end
        end
    end

    % wait before starting    
    if InPar.WaitFinish
        % wait sequentially for each camera, because camera.waitFinish
        %  has been implemented scalarly. No big deal however, because
        %  at the end we'll proceed only when the last of the busy cameras
        %  is free, no matter the order of checking
        for i=Cameras
            Unit.Camera{i}.classCommand('waitFinish');
        end
    end

    % start acquisition on each of the local cameras, using nonblocking
    %  methods
    for i=Cameras
        if Nimages>1
            Unit.Camera{i}.classCommand(sprintf('takeLive(%d)',Nimages));
        else
            Unit.Camera{i}.classCommand('takeExposure');
        end
    end
    
    % restore original timeouts of remote cameras
    if InPar.WaitFinish
        for i=Cameras
            if isa(Unit.Camera{i},'obs.remoteClass')
                Unit.Camera{1}.Messenger.StreamResource.Timeout=timeout(i);
            end
        end
    end

end
