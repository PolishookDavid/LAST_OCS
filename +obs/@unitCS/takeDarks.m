function takeDarks(Unit,Cameras,ExpTime,Nimages,varargin)
% Take a sequence of dark images
%
% Same as takeExposure

% Added by Mathia:
% Assign deafult values if arguments are not given
% (No, not giving the arguments will not set to takeExposure's deafults)

if ~exist('Cameras','var') || isempty(Cameras)
    Cameras=1:numel(Unit.Camera);
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

if ~exist('Nimages','var') || isempty(Nimages)
    Nimages = 10;
end

% end of Mathia's code
    
Unit.takeExposure(Cameras, ExpTime, Nimages, varargin{:}, 'ImType','dark');

