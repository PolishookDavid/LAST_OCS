function [Res] = focusTels(UnitObj,itel,varargin)
% Execute new focus loop on LAST telescope
% Package: +obs.util.tools
% Description: Obtain an image with each focus value, and measure the FWHM
%              as a function of focus. Interpolate the best focus value.
%              The focus loop assumes that there is a backlash in the
%              system. In the begining, the focus is set to StartFocus
%              (In LAST StartFocus is higher than the guess focus value).
%              Next the system is going over some user defined focus values
%              and take image with each focus.
%              The program can adapt the focus based on temperature. This
%              is possible if the OCS object is provided with the sensors
%              class.
% Input  : - focusLoop(OCSObject,varargin)
%            Here OCSObject is the single mount OCS object that contains
%            the mount, camera, and focuser objects.
%            [If sensor object is empty then do not use temperature.
%             Omit SensorObj if absent] TODO
%          - Vector of telescope indices. If empty use all. Default is [].
%          * varargin is pairs of ...,key,val,... where the following keys
%            are available:
%            'FocusGuess' - Best focus guess value.
%                   If vector then this is the best focus value for each
%                   camera. Default is the current focuser position.
%            'HalfRange' - Half range of focus loop (i.e., +/- distance of
%                   focus loop from FocusGuess).
%                   If Half range is not consistent with step size, it will
%                   readjusted.
%                   Default is 200.
%            'Step' - Focus loops steps. Default is 40.
%            'FocusGuessTemp' - If the focus guess parameter is temperature
%                   dependent. This is the nominal temperature of the
%                   FocusGuess value. If NaN ignore temperature.
%                   Default is 25.
%            'FocusTempGrad' - The gradient of the focus with
%                   temperature [focus value/1°C].
%                   Default is 0.
%            'BacklashFocus' - A focus value relative to the estimated best
%                   focus value (- below / + above)
%                   from which to start moving, in order to deal with
%                   backlash. 
%                   The sign of this argument defines the direction of the
%                   backlash. Default is 150.
%            'ExpTime'  - Exposure time. Default is 5 sec.
%            'NimExp'   - Number of images per exposure. Default is 1. NOT
%                         USED YET
%            'ImageHalfSize' - Half size of sub image in which to measure
%                   the focus. If empty use full image. Default is 1000.
%            'SeveralPositions' - Nx2 array of positions at which the focus
%                                 is checked, in pixel coordinates. If empty,
%                                 defaults to image center + 6 positions
%                                 on a circle of radius 2000 pixels around
%                                 it. Only for Method='imageFocus'.
%            'SigmaVec' - Vector of gaussian kernel sigma-width (template
%                   bank) with wich to cross-correlate the image.
%                   This will define the range and resolution of the
%                   measured seeing.
%                   Default is [0.1, logspace(0,1,25)].'.
%            'Plot' - Default is true. Will add to existing plot.
%            'Random' - Report random focus values instead of the result
%                       of the focus estimation routine on the image.
%                       Default false. Useful for wet tests when
%                       the cameras cannot see a starry sky image.
%            'Method' - which algorithm to use to evaluate the focus from
%                       the image. Current options are:
%                       'fwhm_fromBank' (new method, default)
%                       'imageFocus' (old method, based on filter2_snBank)
% Output : - A structure with the focus measurments and best value.
%            The following fields are available:
%            .PosVec   - Vector of tested focus positions.
%            .FocVal   - Vector of FWHM [arcsec] at each tested position.
%            .BestFocusFWHM - Best fit FWHM [arcsec]
%            .BestFocusPos  - Best fit focus value.
%            .Az          - Mount Az [deg]
%            .Alt         - Mount Alt [deg]
%            .AM          - Mount airmass []
% By: Eran Ofek          April 2020 ; complete rev. Enrico Segre August 2021
% Example: [FocRes] = Unit.focusLoop(1) 

    if nargin<2
        itel=[];
    end
    if isempty(itel)
        itel=1:numel(UnitObj.Camera);
    end

    MountObj=UnitObj.Mount;
    CamObj=UnitObj.Camera(itel);
    FocObj=UnitObj.Focuser(itel);

    PlotMarker    = 'o';
    PlotMinMarker = 'p';

    % this for the first camera, TODO, what if other cameras are different?
    effA=CamObj{1}.classCommand('effective_area'); % this is maybe only for QHYccd?
    CenterPos=double([effA.syEff,effA.sxEff]/2);
    Theta     = (0:60:300).';
    DefSeveralPositions = [CenterPos; CenterPos + 2000.*[cosd(Theta), sind(Theta)]];

    InPar = inputParser;
    addOptional(InPar,'FocusGuess',[]);  
    addOptional(InPar,'HalfRange',200);  
    addOptional(InPar,'Step',40);  
    addOptional(InPar,'FocusGuessTemp',25);  
    addOptional(InPar,'FocusTempGrad',0);  
    addOptional(InPar,'BacklashFocus',200);  
    addOptional(InPar,'ExpTime',5);  
    addOptional(InPar,'NimExp',1);  
    addOptional(InPar,'ImageHalfSize',1000);  % If [] use full image
    addOptional(InPar,'SeveralPositions',DefSeveralPositions);  % If [] use full image
    addOptional(InPar,'SigmaVec',[0.1, logspace(0,1,25)].');
    addOptional(InPar,'Plot',true);
    addOptional(InPar,'Random',false);
    addOptional(InPar,'Method','fwhm_fromBank',...
                      @(x)any(strcmp(x,{'fwhm_fromBank','imageFocus'})) );
    parse(InPar,varargin{:});
    InPar = InPar.Results;


    % number of cameras and focusers
    Ncam = numel(itel);

    if InPar.Plot
        Colors = plot.generate_colors(Ncam);
    end


    % ------------- End argument parsing and preliminaries, operate ----

    Res=struct('PosVec',[],'FocVal',[],'BestFocusFWHM',[],'BestFocusPos',[],...
                'Az',[],'Alt',[],'AM',[]);
     
 
    for Icam=1:Ncam
        CamObj{Icam}.classCommand('focusTel(FocObj{Icam})')
        
    end
        
