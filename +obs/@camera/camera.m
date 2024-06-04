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

classdef camera < inst.device
 
    properties
        ImType char            = 'sci';       % The image type: science, flat, bias, dark
        Object char            = '';          % The name of the observed object/field
    end
    
    properties % (GetAccess = public, SetAccess = ?obs.unitCS) % no, also via classCommand
        LastImageName char     = '';          % The name of the last image 
        LastImageFWHM double = NaN; % seeing of LastImage, computed if .ComputeFWHM='always' or 'last'
    end
    
    % telescope
    properties(Hidden)
        Filter char     = '';          % Filter Name
        PixScale double = 1.25;     % image scale, "/pixels
        TelescopeOffset double =[0,0] % HA and Dec offsets w.r.t mount pointing
    end
        
    % limits
    properties(Hidden)    
        MaxExpTime    = 300;        % Maximum exposure time in seconds       
    end
    
    % Camera ID, for labels. Typically set in config file
    properties(Hidden, GetAccess = public, SetAccess = public)
        CameraNumber uint8  = 1         %  1       2      3      4
        CameraPos char      = '';       % 'NE' | 'SE' | 'SW' | 'NW'
        %CCDnum = 0;         % ????   % Perhaps obselete. Keep here until we sure it should be removed
    end
    
    % logging
    properties(Hidden)
        LogFile             = '';      % FileName. If not provided, then if LogFileDir is not available then do not write LogFile.
        LogFileDir;
        ConfigHeader struct = struct;  % structure containing additional header keywords with constants
    end
    
    % save
    properties(Hidden)
        SaveOnDisk logical   = true;   % A flag marking if the images should be wriiten to the disk after exposure
        ImageFormat char     = 'fits';    % The format of the written image
        ComputeFWHM char {mustBeMember(ComputeFWHM,{'never','last','always','omit'})}= 'lastimage'; % compute FWHM:
        % 'never' - don't compute and store LastImageFWHM=NaN, to be clear
        % 'last' - only after single still images or the last one of a sequence 
        % 'always' - each time a neLastImageFWHMw image is received (might be a problem
        %            for short live exposures)
        % 'omit' - don't compute, but don't erase the old LastImageFWHM
        %          either
    end
    
    % display
    properties(Hidden)
        Display              = '';   % 'ds9' | 'matlab' | ''
        Frame double         = [];      % frame number to be passed to ds9
        DisplayZoom double   = 0.08;    % ds9 zoom
        DivideByFlat logical = false;    % subtract dark and divide by flat before display
        %DisplayMatlabFig = 0; % Will be updated after first image  % When presenting image in matlab, on what figure number to present
        %DisplayAllImage = true;   % Display the entire image, using ds9.zoom
        %DisplayZoomValueAllImage = 0.08;  % Value for ds9.zoom, to present the entire image
        %DisplayReducedIm = true;   % Remove the dark and flat field before display
    end
    
    % for saving all the images in a sequence in a buffer
    properties(Hidden) % sequence buffering
        LastSeq = struct('Image',cell(0,1), 'JD', cell(0,1));
        LastSeqFlag logical = false;
    end
    
    properties (Hidden=true, GetAccess=public, SetAccess=private, Transient)
        Ready=struct('flag',true,'reason',''); % if and why the camera can be operated
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
        
    % getter for isReady
    methods
        function r=get.Ready(CameraObj)
            r=struct('flag',false,'reason',CameraObj.CamStatus);
            switch r.reason
                case 'idle'
                    r.flag=true;
            end
        end
    end
    
end