function [Success, Result] = focusTel2(CameraObj, FocuserObj, Args)
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
    %                       This sill define an adaptive step size based on
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
    %            'MaxFWHM' - When estimating the FWHM min, use only balues
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
    % Example: P.Camera{4}.focusTel2(P.Focuser{4});
    
    arguments
        CameraObj
        FocuserObj
        %Args.TempFocTable        = [];  % [Temp, Focus]
        %Args.Temp                = [];
        %Args.FocByTemp logical   = false;
        
        Args.BacklashOffset      = +1000;  % sign signify the backlash diection
        Args.SearchHalfRange     = 300;
        Args.FWHM_Step           = [5 25; 12 50; 25 100]; % [FWHM, step size]
        Args.PosGuess            = [];  % empty - use current position, 36000;
        
        Args.ExpTime             = 3;
        Args.Nim                 = 1;
        Args.PixScale            = 1.25;
        
        Args.HalfSize            = 1000;
        Args.fwhm_fromBankArgs cell = {'SigmaVec',logspace(-0.5,2,25)};
        Args.MaxIter             = 15;
        Args.MaxFWHM             = 6;   % max FWHM to use for min estimation
       
        Args.MinNstars           = 10;
        Args.FitMethod           = 'out1';
       
        Args.Verbose logical     = true;
        Args.Plot logical        = true;
    end
    
    %--- get Limits and current position of focuser
    Limits     = FocuserObj.Limits;
    CurrentPos = FocuserObj.Pos;
    
    if Args.Verbose
        fprintf('Current/Starting focus position: %d\n',CurrentPos);
        fprintf('Limits: %d %d\n',Limits);
    end
    
    % motion direction
    MoveDir    = -sign(Args.BacklashOffset);
    
    if isempty(Args.PosGuess)
        Args.PosGuess = CurrentPos;
    end
    
    % 
    Sucess = false;
    Result.Status     = '';
    Result.BestPos    = NaN;
    Result.BestFWHM   = NaN;
    Result.Counter    = NaN;
    
    if Args.Plot
        figure;
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
        
    ResTable = nan(Args.MaxIter,3);  % % [FocPos, FWHM, Nstars]
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
            [VecFWHM(Iim), VecNstars(Iim)] = imUtil.psf.fwhm_fromBank(Image, Args.fwhm_fromBankArgs{:}, 'HalfSize',Args.HalfSize, 'PixScale',Args.PixScale);
                
        end
        FWHM  = min(25, median(VecFWHM, 'all', 'omitnan')); % very large values not reliable, as fwhm_fromBank doesn't work for donuts
        Nstars = median(VecNstars, 'all', 'omitnan');
        
        %fprintf('\n%d', VecFWHM)
        %fprintf('\n%d', VecNstars)
       
        Step   = MoveDir .* interp1(Args.FWHM_Step(:,1), Args.FWHM_Step(:,2), FWHM, 'nearest', 'extrap');
        FocPos = FocPos + Step;
        if Args.Verbose
            fprintf('   Step=%d\n',Step);
        end


        actualFocPos = FocuserObj.Pos;
        ResTable(Counter,:) = [actualFocPos, FWHM, Nstars];
            
        if Args.Verbose
            fprintf('Sending focuser to: %d. Actual position: %d.\n', FocPos, actualFocPos)
            fprintf('   FocPos=%d    FWHM=%4.1f    Nstars=%d\n',FocPos, FWHM, Nstars);
        end
        if Args.Plot
            plot(FocPos, FWHM, 'bo', 'MarkerFaceColor','b');
            hold on;
            H = gca;
            H.YLim = [0 26];
        end
            
        % look for focus
        % consider only FWHM under 15
        if sum(ResTable(:,2)<15)>4      

            FocStatus = checkForMinimum(ResTable(1:Counter,:));

            switch lower(FocStatus)
                case 'rising'
                    % problem
                    fprintf('\nRising');
                    fprintf('\nFocus likely larger than %d', StartPos);
                    Cont = false;
                    Success       = false;
                    Result.BestPos = Args.PosGuess   % moving back to initial position
        
                case 'found'
                    fprintf('\nFocus found');
                    % focus likely found
                    Cont = false;
                            
                case 'cont'
                    % focus not found
                    fprintf('\nFocus not found');
                    Cont = true;
                otherwise
                    error('Unknown checkForMinimum status');
            end
            
        end                    
                 
        if Cont
            % move focus to: FocPos
            fprintf('\nCont');
            FocuserObj.Pos = FocPos;
            FocuserObj.waitFinish;
        end
    end
     
                
    % truncate not used pre allocated matrix
    ResTable = ResTable(1:Counter,:);
    Result.ResTable = ResTable;
        
    % search for global minimum
    FlagGood = ~isnan(ResTable(:,1)) & ResTable(:,2)>0 & ResTable(:,2)<Args.MaxFWHM & all(ResTable(:,3)>Args.MinNstars);    
    if Counter>=Args.MaxIter
        % focus not found
        Result.Status = 'Max iter reached';
        Success       = false;
        fprintf('\nMax iter reached.')
        Result.BestPos = Args.PosGuess   % moving back to initial position
        
    elseif lower(FocStatus)        
        Result.Status = 'Rising. Focus out of search range.';
        Success       = false;
        Result.BestPos = Args.PosGuess   % moving back to initial position
        
    elseif sum(FlagGood)<3
        Result.Status = 'Number of good FWHM points is smaller than 3';
        Success       = false;
        fprintf('\nFewer than 3 good points.')
        Result.BestPos = Args.PosGuess   % moving back to initial position
    else
        Foc  = ResTable(FlagGood,1);
        FWHM = ResTable(FlagGood,2);
        
        % Estimate minimum FWHM
        % want to use more points in fit
        [Result.BestPos, Result.BestFWHM] = obs.util.tools.minimum123(Foc, FWHM);
        fprintf('\nbest pos %d', Result.BestPos)
        fprintf('\nbest FWHM %d', Result.BestFWHM)
        %fprintf('\nMin? %d', Ismin)
        plot(Result.BestPos, Result.BestFWHM, 'ro', 'MarkerFaceColor','r');

        % current fit routine does not check whether it is a minimum
        if false %~IsMin
            Success = false;
            Result.Status = 'Minimum not found';
        else
            Result.Status = 'Best focus found';
            Success = true;
        end
           
    end
    
    
    %--- move focuser to: BacklashPos
    FocuserObj.Pos = BacklashPos;
    FocuserObj.waitFinish;
    
    %--- move focuser to best focus position: BestPos
            
    if Args.Verbose
        fprintf('\nMoving to best position %d\n', Result.BestPos);
    end
    
    FocuserObj.Pos = Result.BestPos;
    FocuserObj.waitFinish;
    
    
end

% util funs
function Status = checkForMinimum(FocFWHM)
    %
    % requires minimum of 5 points
   
    %Foc  = FocFWHM(:,1);
    FWHM = FocFWHM(:,2);

    %fprintf('\n %d', FocFWHM)
    %fprintf('\nrising? %d (%d > %d)', (FWHM(3:end-2)>mean(FWHM(1:2))), FWHM(3:end-2), mean(FWHM(1:2)))
    %fprintf('\nfound? %d (%d > %d)', any(FWHM(3:end-2)<mean(FWHM(end-1:end))), FWHM(3:end-2), mean(FWHM(end-1:end)))

            
    if FWHM(3:end-2)>mean(FWHM(1:2)+5)
        % focus FWHM is rising near starting point - focus is not there
        Status = 'rising';
    else
        % focus FWHM is decreasing near starting point - ok
        
        if any(FWHM(3:end-2)<mean(FWHM(end-1:end))-2) & min(FWHM(3:end-2))<6
            % minimum likely found
            Status = 'found';
        else
            % minium not found - continue
            Status = 'cont';
        end
    end
    
end
        