% Abstraction class for a single camera
% Package: +obs.camera
% Description: This superclass extends camera driver
%              classes for either the QHY or ZWO detectors.
% Some basic examples:
%   C = instr.QHYCCD ;      % create an empty camera object for a QHY device
%   C.connect               % connect the camera
%
%   C.ExpTime = 1;          % set the Exposure time to 1s
%   C.takeExposure;         % take a single exposure. Save and display the image
%
%   % delete the object
%   C.disconnect
%   clear C


classdef camera < obs.LAST_Handle
 
    properties
        ImType char            = 'sci';       % The image type: science, flat, bias, dark
        Object char            = '';          % The name of the observed object/field
    end
    
    properties % (GetAccess = public, SetAccess = ?obs.unitCS) % no, also via classCommand
        LastImageName char     = '';          % The name of the last image 
    end
    
    properties(Hidden)
        Filter char            = '';          % Filter Name % not in driver
    end
        
    % limits
    properties(Hidden)    
        MaxExpTime    = 300;        % Maximum exposure time in seconds       
    end
    
    % Camera ID, for labels. Typically set in config file
    properties(Hidden, GetAccess = public, SetAccess = public)
        CameraNumber double    = 1         %  1       2      3      4
        CameraPos char         = '';       % 'NE' | 'SE' | 'SW' | 'NW'
    end
        
    properties(Hidden)
        LogFile             = '';          % FileName. If not provided, then if LogFileDir is not available then do not write LogFile.
        LogFileDir;
        ConfigHeader struct = struct;     % structure containing additional header keywords with constants
    end
    
    % save
    properties(Hidden)
        SaveOnDisk logical   = true;   % A flag marking if the images should be wriiten to the disk after exposure
        ImageFormat char     = 'fits';    % The format of the written image
    end
    
    % display
    properties(Hidden)
        Display              = 'ds9';   % 'ds9' | 'matlab' | ''
        Frame double         = [];      % frame number to be passed to ds9
        DisplayZoom double   = 0.08;    % ds9 zoom
        DivideByFlat logical = false;    % subtract dark and divide by flat before display
    end
    
        %DisplayMatlabFig = 0; % Will be updated after first image  % When presenting image in matlab, on what figure number to present
        %DisplayAllImage = true;   % Display the entire image, using ds9.zoom
        %DisplayZoomValueAllImage = 0.08;  % Value for ds9.zoom, to present the entire image
        %DisplayReducedIm = true;   % Remove the dark and flat field before display
        %CCDnum = 0;         % ????   % Perhaps obselete. Keep here until we sure it should be removed
	
    
    properties (Hidden,Transient)        
        Handle;           % Handle to camera driver class        
        ReadoutTimer;     % A timer object to operate after exposure start, to wait until the image is ready.
        SequenceFrame double % progressive frame number when a sequence of exposures is requested
        SequenceLength double % total number of frames requested for the sequence
        % A flag marking if to print software printouts or not (??)
    end
    
    
    % constructor and destructor
    methods
                
        function CameraObj=camera(id)
            % Camera object constructor
            if exist('id','var')
                CameraObj.Id=id;
            end
            % load configuration
            CameraObj.loadConfig(CameraObj.configFileName('createsuper'))
            % add a listener for new images
            addlistener(CameraObj,'LastImage','PostSet',@CameraObj.treatNewImage);
        end
       
        function delete(CameraObj)
        end
        
    end
        
end