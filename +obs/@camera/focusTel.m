function [Success, Result] = focusTel(CameraObj, FocuserObj, Args)
    % Focus a single telescope
    %   This routine can adaptively focus a single telescope, or set its
    %   focus position by a temperature-focus relation.
    % Input  : - A camera object.
    %          - A focuser object.
    %          * ...,key,val,...
    %            'TempFocTable' - [Temp, Focus] two column matrix.
    %                       Default is [].
    %            'Temp'         - Current temperature.
    %                       Default is [].
    %            'FocByTemp' - A logical indicating if to focus by
    %                       focus-temperature relation.
    %                       If true, then 'Temp' and 'TempFocTable' must be
    %                       provided.
    %                       Default is false.
    %            'BacklashOffset' - Backlash offset.
    %                       sign indicate the backlash direction. If +,
    %                       then start with position larger than the
    %                       first guess focus value.
    %                       Default is +1000.
    %            'SearchHalfRange' - focus search upper half range.
    %                       Default is 600.
    %            'FWHM_Step' - [FWHM, step_size] two column matrix.
    %                       This will define an adaptive step size based on
    %                       the FWHM.
    %                       Default is [3 40; 20 80; 30 120]
    %            'PosGuess' - Guess focus position. If empty, use
    %                   focus-temperature table, and if not available, then use
    %                   current position.
    %            'ExpTime' - Image exposure time. Default is 3 [s].
    %            'Nim' - Number of images to average over. Default is 1.
    %            'PixScale' - Pixel scale. Default is 1.25 [arcsec/pix].
    %            'HalfSize' - Image half size inw which to estimate focus.
    %                   Default is 1000.
    %            'fwhm_fromBankArgs' - A cell array of additional arguments
    %                   to pass to imUtil.psf.fwhm_fromBank
    %                   Default is {}.
    %            'MaxIter' - Maximum number of iterations. Default is 15.
    %            'MaxFWHM' - When estimating the FWHM min, use only values
    %                   with FWHM better than this vale. Default is 6 [arcsec].
    %            'MinNstars' - Min. required number of stars.
    %                   Default is 10.
    %            'FitMethod' - Fit min method. Option are:
    %                   'out1' - remove largest outler above 3 sigma.
    %                   'fitpar' - simple parabola fitting.
    %                   Default is 'out1'.
    % Output : - A sucess flag.
    %          - A Result structure with the following fields:
    %            .Status
    %            .BestPos
    %            .BestFWHM
    %            .Counter
    % Author : Eran Ofek (Apr 2022) Nora (Oct. 2022)
    % Example: P.Camera{4}.focusTel(P.Focuser{4});
    
    arguments
        CameraObj
        FocuserObj
        
        Args.BacklashOffset      = +1000;  % sign signify the backlash diection
        Args.SearchHalfRange     = []; % if empty will choose small range if FWHM already good and large one otherwise
        Args.FWHM_Step           = [5 40; 20 60; 25 100]; % [FWHM, step size]
        Args.PosGuess            = [];  % empty - use current position
        
        Args.ExpTime             = 3;
        Args.Nim                 = 1;
        Args.PixScale            = 1.25;
        
        Args.ImageHalfSize       = 1000;
        Args.fwhm_fromBankArgs cell = {'SigmaVec',[0.1, logspace(0,1,25)].'}; %logspace(-0.5,2,25)};
        Args.MaxIter             = 20;
        Args.MaxFWHM             = 8;   % max FWHM to use for min estimation
       
        Args.MinNstars           = 10;
        Args.FitMethod           = 'out1';
       
        Args.Verbose logical     = true;
        Args.Plot logical        = true;
    end
    
    %CameraObj  = UnitObj.Camera{itel};
    %FocuserObj = UnitObj.Focuser{itel};
    
    
    %--- get Limits and current position of focuser
    Limits     = FocuserObj.Limits;
    CurrentPos = FocuserObj.Pos;
    
    % set ImgType to focus
    previousImgType = CameraObj.ImType;
    CameraObj.ImType = 'focus';
    
    % take exposure
    CameraObj.takeExposure(Args.ExpTime);
            
    % wait till camera is ready
    CameraObj.waitFinish;
                
    % get image
    Image = CameraObj.LastImage;
    [InitialFWHM, InitialNstars] = imUtil.psf.fwhm_fromBank(Image, 'HalfSize',Args.ImageHalfSize);

    
    % don't move far away if focus already good
    if isempty(Args.SearchHalfRange)
        if (InitialFWHM<5) & isempty(Args.PosGuess)
            Args.SearchHalfRange=250;
        else
            Args.SearchHalfRange=500;
        end
    else
    end

    if Args.Verbose
        fprintf('Current/Starting focus position: %d\n',CurrentPos);
        fprintf('Focuser limits: %d %d\n',Limits);
        fprintf('Initial Focus %d\n',InitialFWHM);
        %fprintf('SearchHalfRange set to %d\n', SearchHalfRange);
    end
    
    
    % motion direction
    MoveDir    = -sign(Args.BacklashOffset);
    
    if isempty(Args.PosGuess)
        Args.PosGuess = CurrentPos;
    end
    
    % 
    Success = false;
    Result.Status     = '';
    Result.BestPos    = NaN;
    Result.BestFWHM   = NaN;
    Result.Counter    = NaN;
    
    if Args.Plot
        figure;
        plot(CurrentPos, min(25, InitialFWHM), 'co', 'MarkerFaceColor','c');
        hold on;
        title('Focuser '+string(CameraObj.classCommand('CameraNumber'))+' - '+datestr(now,'HH:MM:SS'));
    end
    
    % move to backlash position
    BacklashPos = Args.PosGuess + Args.BacklashOffset;
        
    if BacklashPos>max(Limits)
        error('BacklashPos is above upper focuser limit');
    end
        
    % move to: BacklashPos
    FocuserObj.Pos = BacklashPos;
    FocuserObj.waitFinish;
        
    StartPos = Args.PosGuess + Args.SearchHalfRange;
    % move to upper range: StartPos
    FocuserObj.Pos = StartPos;
    FocuserObj.waitFinish;
        
    FocPos = StartPos;
        
    ResTable = nan(Args.MaxIter,4);  % % [FocPos, FWHM, Nstars, FlagGood]
    Cont     = true;
    Counter  = 0;
    while Cont & Counter<Args.MaxIter
        Counter        = Counter + 1;
        fprintf('\n\n %d\n', Counter)
        Result.Counter = Counter;

        % take exposure
        for Iim=1:1:Args.Nim
                
            % take exposure
            CameraObj.takeExposure(Args.ExpTime);
            
            % wait till camera is ready
            CameraObj.waitFinish;
                
            % get image
            Image = CameraObj.LastImage;
                
            % measure focus value
            %[VecFWHM(Iim), VecNstars(Iim)] = imUtil.psf.fwhm_fromBank(Image, Args.fwhm_fromBankArgs{:}, 'HalfSize',Args.HalfSize, 'PixScale',Args.PixScale);
            [VecFWHM(Iim), VecNstars(Iim)] = imUtil.psf.fwhm_fromBank(Image, 'HalfSize',Args.ImageHalfSize);

        end
        FWHM  = min(25, median(VecFWHM, 'all', 'omitnan')); % very large values not reliable, as fwhm_fromBank doesn't work for donuts
        Nstars = median(VecNstars, 'all', 'omitnan');
        
        %fprintf('\n%d', VecFWHM)
        %fprintf('\n%d', VecNstars)
        
        actualFocPos = FocuserObj.Pos;
        FlagGood = ~isnan(actualFocPos) & FWHM>0.5 & FWHM<Args.MaxFWHM & Nstars>Args.MinNstars;
        ResTable(Counter,:) = [actualFocPos, FWHM, Nstars, FlagGood];
            
        if Args.Verbose
            fprintf('Sent focuser to: %d. Actual position: %d.\n', FocPos, actualFocPos);
            fprintf('   FocPos=%d    FWHM=%4.1f    Nstars=%d\n',FocPos, FWHM, Nstars);
        end


        if Args.Plot
            if FlagGood
                plot(actualFocPos, FWHM, 'bo', 'MarkerFaceColor','b');
            else
                plot(actualFocPos, FWHM, 'bo', 'MarkerFaceColor','w');
            end
            
            hold on;
            H = gca;
            H.YLim = [0 26];
        end
        
        
        Step   = MoveDir .* interp1(Args.FWHM_Step(:,1), Args.FWHM_Step(:,2), FWHM, 'nearest', 'extrap');
        FocPos = FocPos + Step;
        if Args.Verbose
            fprintf('   Step=%d\n',Step);
        end

        % look for focus
        % consider only FWHM under 23
        if sum(ResTable(:,2)<23)>4      

            FocStatus = checkForMinimum(ResTable(1:Counter,:));

            switch lower(FocStatus)
                case 'rising'
                    % problem
                    fprintf('\nRising');
                    fprintf('\nFocus likely larger than %d', StartPos);
                    Cont = false;
        
                case 'found'
                    fprintf('\nFocus found');
                    % focus likely found
                    Cont = false;
                            
                case 'cont'
                    % focus not found
                    fprintf('\nFocus yet not found');
                    Cont = true;
                otherwise
                    error('Unknown checkForMinimum status');
            end
            
        end                    
                 
        if Cont
            % move focus to: FocPos
            FocuserObj.Pos = FocPos;
            FocuserObj.waitFinish;
        end
    end
     
    
                
    % truncate not used pre allocated matrix
    ResTable = ResTable(1:Counter,:);
    Result.ResTable = ResTable
        
    
    % search for global minimum    
    if Counter>=Args.MaxIter
        % focus not found
        Result.Status = 'Max iter reached';
        Success       = false;
        fprintf('\nMax iter reached.')
        Result.BestPos = Args.PosGuess   % moving back to initial position
	elseif sum(ResTable(:,4))<3
        Result.Status = 'Number of good FWHM points is smaller than 3';
        Success       = false;
        fprintf('\nFewer than 3 good points.')
        Result.BestPos = Args.PosGuess   % moving back to initial position
        
    else
        switch lower(FocStatus)
            case 'rising'        
                Result.Status = 'Rising. Focus out of search range.';
                Success       = false;
                Result.BestPos = Args.PosGuess;   % moving back to initial position
        
            case 'found'
                            
                % using only good points
                Foc  = ResTable(ResTable(:,4)==1,1);
                FWHM = ResTable(ResTable(:,4)==1,2);
        
                % Estimate minimum FWHM
                [Result.BestPos, Result.BestFWHM] = fitParabola(Foc,FWHM);
                %ransacLinear([Foc,FWHM], Args)
                [~,~] = fitRansacParabola(Foc,FWHM)
                plot(Result.BestPos, Result.BestFWHM, 'ro', 'MarkerFaceColor','r');

                fprintf('\nbest pos %d', Result.BestPos)
                fprintf('\nbest FWHM %d', Result.BestFWHM)
                
                Result.Status = 'Found.'
                Success       = true;

        end
           
    end
    
    % go back to previous imgtype
    CameraObj.ImType = previousImgType;
    
    %--- move focuser to: BacklashPos
    FocuserObj.Pos = BacklashPos;
    FocuserObj.waitFinish;
    
    %--- move focuser to best focus position: BestPos
            
    if Args.Verbose
        fprintf('\nMoving to best position %d\n', Result.BestPos);
        fprintf('\nFinished at %s\n', datestr(now,'HH:MM:SS.FFF'));
    end
    
    FocuserObj.Pos = Result.BestPos;
    FocuserObj.waitFinish;
    
    text(Result.BestPos, Result.BestFWHM+4,string(Result.BestFWHM)+' arcsec at '+string(Result.BestPos)+' '+datestr(now,'HH:MM:SS.FFF')) 
    saveas(gcf,'~/Desktop/Nora/focus_figs/focusres_'+string(CameraObj.classCommand('CameraNumber'))+'_'+datestr(now,'HH:MM:SS')+'.png') 

end

% util funs
function Status = checkForMinimum(FocFWHM)
    %
    % requires minimum of 5 points
   
    FWHM = FocFWHM(:,2);

    %%%%% rising case not yet tested %%%%%%%
    if min(FWHM(end-2:end))>max(FWHM(1:2)+5)
        % focus FWHM is rising near starting point - focus is not there
        Status = 'rising';
    else
        % focus FWHM is decreasing near starting point - ok
        
        lowestPoint = min(FWHM(3:end-2));
        fprintf('lowestPoint: %f min beginning: %f min end: %f', lowestPoint,min(FWHM(1:2)),min(FWHM(end-1:end)))

        if lowestPoint<min(FWHM(end-1:end)-1) & lowestPoint<min(FWHM(1:3)-1) & min(FWHM(3:end-2))<6       
            % minimum likely found
            Status = 'found';
        else
            % minium not found - continue
            Status = 'cont';
        end
    end
    
end
        


% not yet working
function [BestPos, BestFWHM] = fitRansacParabola(Foc,FWHM)

    % transform x-values to get small numbers
    Foc_small = (Foc-median(Foc))/100;
        
    H = [ones(length(Foc),1), Foc_small, Foc_small.^2];

    [FlagGood, BestPar, BestStd] = tools.math.fit.ransacLinearModel(H, FWHM, 'Nsim',200, 'FracPoints',0.7, 'NsigmaClip', [5,5])

    
    x_new = linspace(min(Foc)-50, max(Foc)+50,20)';
    x_new_small = (x_new-median(Foc))/100;

    plot(Foc(FlagGood), FWHM(FlagGood), 'xk')
    plot(x_new, BestPar(1)+BestPar(2)*x_new+BestPar(3)*x_new.^2,'k')

    
    %BestPos = (BestPar(1)*100)+median(Foc);
    BestPos = 34080;
    BestFWHM = BestPar(1);
end
  

function [BestPos, BestFWHM] = fitParabola(Foc,FWHM)

    makePlot = true;

    % transform x-values to get small numbers
    x = (Foc-median(Foc))/100;
    
    % find starting point
    [value, ind] = min(FWHM);
    x0 = [value 2.5 x(ind)];

    % define parabola and fit
    fitfun = fittype( @(a,b,c,x) a+b*(x-c).^2);
    [fitted_curve,gof] = fit(x,FWHM,fitfun,'StartPoint',x0)
    res = coeffvalues(fitted_curve);
    BestPos = (res(3)*100)+median(Foc);
    BestFWHM = fitted_curve(res(3));
    
    % Plot results
    if makePlot
        x_new = linspace(min(Foc)-50, max(Foc)+50,20)';
        x_new2 = (x_new-median(Foc))/100;

        plot(x_new, fitted_curve(x_new2), 'r');
        %scatter(Foc, FWHM, 'og');
        %scatter(BestPos, BestFWHM, 'ok');
        
    end
end