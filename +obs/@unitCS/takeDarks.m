function takeDarks(Unit,Cameras,ExpTime,Nimages,Args)
% Take a sequence of dark images
%
% Same as takeExposure

% Added by Mathia:
% Assign deafult values if arguments are not given
% (No, not giving the arguments will not set to takeExposure's deafults)

arguments
    Unit
    Cameras = [];
    ExpTime = 20;
    Nimages = 20;
    Args.takeExposureArgs cell   = {};
end

if ExpTime>5 || Nimages==1
    Unit.takeExposure(Cameras, ExpTime, Nimages, Args.takeExposureArgs{:},...
                      'ImType','dark', 'Object',[]);
else
    % loop on single exposures, to be sure that they can be saved
    for i=1:Nimages
        Unit.takeExposure(Cameras, ExpTime, 1, Args.takeExposureArgs{:},...
                          'ImType','dark', 'Object',[]);
        Unit.readyToExpose(Cameras,'Wait',true,'Timeout',ExpTime+7);
    end
end
    
