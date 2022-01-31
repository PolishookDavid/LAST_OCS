function takeDarks(Unit,Cameras,ExpTime,Nimages,varargin)
% Take a sequence of dark images
%
% Same as takeExposure

Unit.takeExposure(Cameras, ExpTime, Nimages, varargin{:}, 'ImType','dark');

