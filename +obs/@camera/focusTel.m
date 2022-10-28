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
    % Author : Eran Ofek (Apr 2022)
    % Example: P.Camera{4}.focusTel(P.Focuser{4});
    
    arguments
        CameraObj
        FocuserObj
        Args.TempFocTable        = [];  % [Temp, Focus]
        Args.Temp                = [];
        Args.FocByTemp logical   = false;
        
        Args.BacklashOffset      = +1000;  % sign signify the backlash diection
        Args.SearchHalfRange     = 600;
        Args.FWHM_Step           = [3 40; 20 80; 30 120]; % [FWHM, step size]
        Args.PosGuess            = [];  % empty - use current position, 36000;
        
        Args.ExpTime             = 3;
        Args.Nim                 = 1;
        Args.PixScale            = 1.25;
        
        Args.HalfSize            = 1000;
        Args.fwhm_fromBankArgs cell = {};
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
        % attempt using temperature
        if ~isempty(Args.TempFocTable) && ~isempty(Args.Temp)
            % FocusTable and Temp are given
            Args.PosGuess = interp1(Args.TempFocTable(:,1), Args.TempFocTable(:,2), Args.Temp, 'linear', 'extrap');    
        else
            Args.PosGuess = CurrentPos;
        end
    end
    
    % 
    Success = false;
    Result.Status     = '';
    Result.BestPos    = NaN;
    Result.BestFWHM   = NaN;
    Result.Counter    = NaN;
    
    if Args.Plot
        figure;
    end
    
    if Args.FocByTemp
        % focus only based on temperature
        
        if ~isempty(Args.TempFocTable) && ~isempty(Args.Temp)
            % FocusTable and Temp are given
            BestPos         = Args.PosGuess;
            BacklashPos     = BestPos + Args.BacklashOffset;
            Result.BestVal  = BestPos;
            Result.TempOnly = true;
            Result.Status   = 'Focus based on temperature';
            Success          = true;
        end
    else
        % search for best focus
        
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
        
        ResTable = nan(30,3);  % % [FocPos, FWHM, Nstars]
        Cont     = true;
        Counter  = 0;
        while Cont
            Counter        = Counter + 1;
            Result.Counter = Counter;
            
            % take exposure
            for Iim=1:1:Args.Nim
                %--- wait till camera is ready
                
                % take exposure
                CameraObj.takeExposure(Args.ExpTime);
            
                % wait till camera is ready
                CameraObj.waitFinish;
                
                % get image
                Image = CameraObj.LastImage;
                
                % measure focus value
                [VecFWHM(Iim), VecNstars(Iim)] = imUtil.psf.fwhm_fromBank(Image, Args.fwhm_fromBankArgs{:}, 'HalfSize',Args.HalfSize, 'PixScale',Args.PixScale);
                
            end
            FWHM  = median(VecFWHM, 'all', 'omitnan');
            Nstars = median(VecNstars, 'all', 'omitnan');
            
            
            Step   = MoveDir .* interp1(Args.FWHM_Step(:,1), Args.FWHM_Step(:,2), FWHM, 'nearest', 'extrap');
            FocPos = FocPos + Step;
            
            ResTable(Counter,:) = [FocPos, FWHM, Nstars];
            
            if Args.Verbose
                fprintf('   FocPos=%d    FWHM=%4.1f    Nstars=%d\n',FocPos, FWHM, Nstars);
            end
            if Args.Plot
                plot(FocPos, FWHM, 'bo', 'MarkerFaceColor','b');
                hold on;
                H = gca;
                H.YLim = [0 15];
            end
            
            % look for focus
            if Counter>4
                
                if Counter>Args.MaxIter
                    Cont = false;
                    % focus not found
                    Result.Status = 'Max iter reached';
                    
                else

                    FocStatus = checkForMinimum(ResTable(1:Counter,:));

                    switch lower(FocStatus)
                        case 'rising'
                            % problem
                            Cont = false;
                            Result.Status = 'Focus is rising near starting point';
                        case 'found'
                            % focus likely found
                            Cont = false;
                            
                        case 'cont'
                            % focus not found
                            Cont = true;
                        otherwise
                            error('Unknown checkForMinimum status');
                    end
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
        Result.ResTable = ResTable;
        
        % search for global minimum
        FlagGood = ~isnan(ResTable(:,1)) & ResTable(:,2)>0 & ResTable(:,2)<Args.MaxFWHM & all(ResTable(:,3)>Args.MinNstars);
        if sum(FlagGood)<3
            Result.Status = 'Number of good FWHM points is smaller than 3';
            Success       = false;
        else
            Foc  = ResTable(FlagGood,1);
            FWHM = ResTable(FlagGood,2);
        
            % Estimate minimum FWHM
            [Result.BestPos, Result.BestFWHM, IsMin] = tools.find.fitParabolicMin(Foc, FWHM, 'Method',Args.FitMethod);
            if ~IsMin
                Success = false;
                Result.Status = 'Minimum was not found';
            else
                Result.Status = 'Best focus found';
                Success = true;
            end
            
            
        end
    end
    
    
    %--- move focuser to: BacklashPos
    FocuserObj.Pos = BacklashPos;
    FocuserObj.waitFinish;
    
    %--- move focuser to best focus position: BestPos
    FocuserObj.Pos = Result.BestPos;
    FocuserObj.waitFinish;
    
    
end

% util funs
function Status = checkForMinimum(FocFWHM)
    %
    % requires minimum of 5 points
   
    Foc  = FocFWHM(:,1);
    FWHM = FocFWHM(:,2);
    
    if FWHM(3:end-2)>mean(FWHM(1:2))
        % focus FWHM is rising near starting point - focus is not there
        Status = 'rising';
    else
        % focus FWHM is decreasing near starting point - ok
        
        if any(FWHM(3:end-2)<mean(FWHM(end-1:end)))
            % minimum likely found
            Status = 'found';
        else
            % minium not found - continue
            Status = 'cont';
        end
    end
    
end
        