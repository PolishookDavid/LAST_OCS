function [Success, Result] = getFocusGuess(UnitObj, itel, Args)
    % Scan a large range of focus ticks to get an initial guess when far
    % off. Run it if the initial guess is too bad for focusTel.
    % Input  : - The unit object.
    %          - focuser number 1,2,3, or 4.

    arguments
        UnitObj
        itel
        
        Args.ExpTime             = 3;       
        Args.StepSize           = 1000;
       
        Args.Verbose logical     = true;
        Args.Plot logical        = true;
    end
    
    CameraObj  = UnitObj.Camera{itel};
    FocuserObj = UnitObj.Focuser{itel};
    
        % set ImgType to focus
    previousImgType = CameraObj.ImType;
    CameraObj.ImType = 'focus';
    
    % disable automatic saving (won't work in callback)
    CurrentSaveImage=CameraObj.SaveOnDisk;
    CameraObj.SaveOnDisk=false;
    % TODO restore it at the end
    
    % wait till camera is ready
    CameraObj.waitFinish;

    % take exposure
    % image is read with a callback - nogood when launched via messenger
    % UnitObj.takeExposure(itel,Args.ExpTime);
    CameraObj.startExposure(Args.ExpTime);
                
    % retrieve and save image explicitely, not via callbacks (in order to work also
    %  when the command is received from a messenger)
    pause(Args.ExpTime)
    CameraObj.collectExposure;
    UnitObj.saveCurImage(itel)
                
    % get image
    Image = CameraObj.LastImage;
    
    ACwithinRadius = focusInitialGuess(Image)
    Success = false;
    Result = 0;
end
   

function [ACwithinRadius] = focusInitialGuess(Image, Args)
    % Calculate the autocorrelation of an image and measure how peaked it
    % is. If it returns a large value we are within +/- 1500 ticks of the 
    % focus.
    % Input  : - A 2D image or a cube of images in which the image index is
    %            in the 3rd dimension.
    %          * ...,key,val,...
    %            'Radius' - A radius up to which to calculate the radial
    %                   profile, or a vector of radius edges.
    %                   If empty, then set it to the smallest image dim.
    %                   Default is [].
    %            'Step' - Spep size for radial edges. Default is 1.
    % Output : - A structure array with element per image.
    %            The following fields are available:
    %            .R - radius
    %            .N - number of points in each radius bin.
    %            .MeanR - Mean radius of points in bin.
    %            .MeanV - Mean image val of points in bin.
    %            .MedV - Median image val of points in bin.
    %            .StdV - Std image val of points in bin.
    % Author : Nora (Jan 2023)
    % Example: Frac = focusInitialGuess(I.Image);
        
    arguments
        Image
        Args.Radius        = 20;   
        Args.CropSize      = 1000;
        Args.Plot          = false;
    end
    
    cutout = int64((size(Image)+[-Args.CropSize;Args.CropSize])/2);
    
    ResImage = Image(cutout(1):cutout(2),cutout(3):cutout(4));
    ResImage = ResImage-nanmedian(ResImage, 'all');

    p = prctile(ResImage,[31.73 68.27],"all");
    std = (p(2)-p(1))/2;
    ResImage = ResImage/std;
    
    % zero non-significant pixels; didn't get it to work
    %ResImage(ResImage<5)=0.1;

    AC1= imUtil.filter.autocor(ResImage);


    ACwidth = imUtil.psf.radialProfile(AC1,[],'Radius',min(100, Args.CropSize/2));
    
    % first bin is autocorrelation without shift, not relevant
    ACwidth.MeanV(1) = 0;

    if Args.Plot
        figure;
        plot(ACwidth.R, cumsum(ACwidth.MeanV)/sum(ACwidth.MeanV))
        drawnow
        %hold
    end

    ACwithinRadius = (sum(ACwidth.MeanV(1:20))/sum(ACwidth.MeanV));
    %AutoCorrHalfWidthRadius = min(ACwidth.R(cumsum(ACwidth.MeanV)/sum(ACwidth.MeanV)>=0.5));
    
end