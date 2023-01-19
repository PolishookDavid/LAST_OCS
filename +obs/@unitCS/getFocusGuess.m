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
        Args.MaxIter             = 3;
        Args.Verbose logical     = true;
        Args.Plot logical        = true;
    end
    
    CameraObj  = UnitObj.Camera{itel};
    FocuserObj = UnitObj.Focuser{itel};
    
    
    Success = false;
    Result.Status     = '';
    Result.BestPos    = NaN;
    Result.BestFrac   = NaN;
    Result.Counter    = NaN;
    
    
    % set ImgType to focus
    previousImgType = CameraObj.ImType;
    CameraObj.ImType = 'focus';
    
    % disable automatic saving (won't work in callback)
    CurrentSaveImage=CameraObj.SaveOnDisk;
    CameraObj.SaveOnDisk=false;
    % TODO restore it at the end
    
    Limits     = FocuserObj.Limits;
    OrigPos = FocuserObj.Pos;
        
    if Args.Plot
        figure;
        grid on
        hold on;
        %title('Focuser '+string(CameraObj.classCommand('CameraNumber'))+' - '+datestr(now,'HH:MM:SS'));
        drawnow
    end
    
    % move to: BacklashPos
    FocPos = Limits(2)-10;
    
    if Args.Verbose
        UnitObj.report('\n\nStart searching for focus guess from %d\n',FocPos);
    end

    FocuserObj.Pos = FocPos;
    pause(10);
    FocuserObj.waitFinish;
    
    ResTable = nan(Args.MaxIter,2);  % [FocPos, ACFrac]
    Cont     = true;
    Counter  = 0;
    while Cont && Counter<Args.MaxIter && FocPos> Limits(1)
        Counter        = Counter + 1;
        
        Result.Counter = Counter;

        % take exposure
        CameraObj.startExposure(Args.ExpTime);            
            
        % wait
        pause(Args.ExpTime)
                
        % save image explicitely, not via callback (in order to work also
        %  when the command is received from a messenger)
        CameraObj.collectExposure;
        UnitObj.saveCurImage(itel)

        % get image
        Image = AstroImage({CameraObj.LastImageName}).Image;
        ACwithinRadius = focusInitialGuess(Image)
        
        % for testing during day; delete later
        %if Counter==2
        %    ACwithinRadius = 0.8;
        %end
        
        actualFocPos = FocuserObj.Pos;
        ResTable(Counter,:) = [actualFocPos, ACwithinRadius];
        

            
        if Args.Verbose
            UnitObj.report('\n\n %d\n', Counter)
            UnitObj.report('Sent focuser to: %d. Actual position: %d.\n', FocPos, actualFocPos);
            UnitObj.report('   FocPos=%d    ACFrac=%.3f\n',FocPos, ACwithinRadius);
        end


        if Args.Plot
            plot(actualFocPos, ACwithinRadius, 'co', 'MarkerFaceColor','c');
            grid on
            set(gca,'FontSize',10,'XtickLabel',string(get(gca,'Xtick')))
            
            hold on;
            H = gca;
            drawnow
        end
        
        
        FocPos = FocPos - Args.StepSize;
        
        
        [maxACFrac, maxACFracInd] = max(ResTable(1:Counter,2));
        
        if (maxACFrac-median(ResTable(1:Counter,2)))>0.5
            UnitObj.report('	Focus guess found.\n\n');
            Cont = false;
            Success = true;    
            Result.Status     = 'Focus guess found';
            Result.BestPos    = ResTable(maxACFracInd,1);
            Result.BestFrac   = maxACFrac;
            ResTable
            % move focus to: FocPos
            FocuserObj.Pos = Result.BestPos;
            FocuserObj.waitFinish;
        end
            
        if Cont
            % move focus to: FocPos
            FocuserObj.Pos = FocPos;
            FocuserObj.waitFinish;
        end
    end

    if Success == false
        Result.Status     = 'No focus guess found';
    
        if Args.Verbose            
            UnitObj.report('No focus guess found.\n');
            UnitObj.report('Returning to original position at %d\n',OrigPos);

        end
        
        FocuserObj.Pos = OrigPos;
        FocuserObj.waitFinish;
    end
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