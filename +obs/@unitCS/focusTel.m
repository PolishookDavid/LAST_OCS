function [Success, Result] = focusTel(UnitObj, itel, Args)
    % Focus a single telescope
    %   This routine can adaptively focus a single telescope, or set its
    %   focus position by a temperature-focus relation.
    % Input  : - The unit object.
    %          - focuser number 1,2,3, or 4.
    %          * ...,key,val,...
    %            'BacklashOffset' - Backlash offset.
    %                       sign indicate the backlash direction. If +,
    %                       then start with position larger than the
    %                       first guess focus value.
    %                       Default is +1000.
    %            'SearchHalfRange' - focus search upper half range.
    %                       Default is 200 to 500 depending on initial FWHM.
    %            'FWHM_Step' - [FWHM, step_size] two column matrix.
    %                       This will define an adaptive step size based on
    %                       the FWHM.
    %                       Default is [5 40; 20 60; 25 100]
    %            'PosGuess' - Guess focus position. If empty, use
    %                   current position.
    %            'ExpTime' - Image exposure time. Default is 3 [s].
    %            'PixScale' - Pixel scale. Default is 1.25 [arcsec/pix].
    %            'HalfSize' - Image half size inw which to estimate focus.
    %                   Default is 1000.
    %            'fwhm_fromBankArgs' - A cell array of additional arguments
    %                   to pass to imUtil.psf.fwhm_fromBank
    %                   Default is {}.
    %            'MaxIter' - Maximum number of iterations. Default is 20.
    %            'MaxFWHM' - When estimating the FWHM min, use only values
    %                   with FWHM better than this vale. Default is 8 [arcsec].
    %            'MinNstars' - Min. required number of stars.
    %                   Default is 10.
    %             'Verbose' - Bool. Print numbers in slave session. Default
    %                       is true.
    %             'Plot' - Bool. Plot focus curve. Default is true.
    % Output : - A sucess flag.
    %          - A Result structure with the following fields:
    %            .Status
    %            .BestPos
    %            .BestFWHM
    %            .Counter
    % Author : Eran Ofek (Apr 2022) Nora (Jan. 2023)
    % Example: in Slave session P.focusTel(4);
    %          in Master session P.Slave{4}.Messenger.send('P.focusTel(4)')
    
    arguments
        UnitObj
        itel
        
        Args.BacklashOffset      = +1000;  % sign signify the backlash diection
        Args.SearchHalfRange     = []; % if empty will choose small range if FWHM already good and large one otherwise
        Args.FWHM_Step           = [5 40; 20 60; 25 100]; % [FWHM, step size]
        Args.PosGuess            = [];  % empty - use current position
        
        Args.ExpTime             = 3;
        Args.PixScale            = 1.25;
        
        Args.ImageHalfSize       = 1000;
        Args.fwhm_fromBankArgs cell = {'SigmaVec',[0.1, logspace(0,1,25)].'}; %logspace(-0.5,2,25)};
        Args.MaxIter             = 20;
        Args.MaxFWHM             = 8;   % max FWHM to use for min estimation
       
        Args.MinNstars           = 10;
       
        Args.Verbose logical     = true;
        Args.Plot logical        = true;
    end
    
    CameraObj  = UnitObj.Camera{itel};
    FocuserObj = UnitObj.Focuser{itel};
    
    
    %--- get Limits and current position of focuser
    Limits     = FocuserObj.Limits;

    CurrentPos = FocuserObj.Pos;
    
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
    [InitialFWHM, ~] = imUtil.psf.fwhm_fromBank(Image, 'HalfSize',Args.ImageHalfSize);

    
    % don't move far away if focus already good
    if isempty(Args.SearchHalfRange)
        if (InitialFWHM<5) && isempty(Args.PosGuess)
            Args.SearchHalfRange=200;
        else
            Args.SearchHalfRange=500;
        end
    else
    end

    if Args.Verbose
        UnitObj.report('\n\nCurrent/Starting focus position: %d\n',CurrentPos);
        UnitObj.report('Focuser limits: %d %d\n',Limits);
        UnitObj.report('Initial Focus %d\n',InitialFWHM);
        UnitObj.report('SearchHalfRange set to %d\n\n', Args.SearchHalfRange);
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
    
    MaxPlotFWHM=26;
    
    if Args.Plot
        figure;
        plot(CurrentPos, min(MaxPlotFWHM, InitialFWHM), 'co', 'MarkerFaceColor','c');
        grid on
        set(gca,'FontSize',10,'XtickLabel',string(get(gca,'Xtick')))
        hold on;
        title('Focuser '+string(CameraObj.classCommand('CameraNumber'))+' - '+datestr(now,'HH:MM:SS'));
        drawnow
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
    while Cont && Counter<Args.MaxIter
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
        Image = CameraObj.LastImage;
                
        % measure focus value
        [FWHM, Nstars] = imUtil.psf.fwhm_fromBank(Image, 'HalfSize',Args.ImageHalfSize);
        FWHM  = min(25, FWHM); % very large values not reliable, as fwhm_fromBank doesn't work for donuts
        
        % adding outlier on purpose. delete after testing!
        %if Counter==5
        %    FWHM = 6.5;
        %end
        
        actualFocPos = FocuserObj.Pos;
        FlagGood = ~isnan(actualFocPos) & FWHM>0.5 & FWHM<Args.MaxFWHM & Nstars>Args.MinNstars;
        ResTable(Counter,:) = [actualFocPos, FWHM, Nstars, FlagGood];
            
        if Args.Verbose
            UnitObj.report('\n\n %d\n', Counter)
            UnitObj.report('Sent focuser to: %d. Actual position: %d.\n', FocPos, actualFocPos);
            UnitObj.report('   FocPos=%d    FWHM=%4.1f    Nstars=%d\n',FocPos, FWHM, Nstars);
        end


        if Args.Plot
            if FlagGood
                plot(actualFocPos, FWHM, 'bo', 'MarkerFaceColor','b');
            else
                plot(actualFocPos, FWHM, 'bo', 'MarkerFaceColor','w');
            end
            grid on
            set(gca,'FontSize',10,'XtickLabel',string(get(gca,'Xtick')))
            
            hold on;
            H = gca;
            %H.YLim = [0.8 MaxPlotFWHM];
            drawnow
        end
        
        
        Step   = MoveDir .* interp1(Args.FWHM_Step(:,1), Args.FWHM_Step(:,2), FWHM, 'nearest', 'extrap');
        FocPos = FocPos + Step;
        if Args.Verbose
            UnitObj.report('   Step=%d\n',Step);
        end

        % look for focus
        % consider only FWHM under 23
        if sum(ResTable(:,2)<23)>4      

            FocStatus = checkForMinimum(ResTable(1:Counter,:));

            switch lower(FocStatus)
                case 'rising'
                    % problem
                    if Args.Verbose
                        UnitObj.report('	Rising');
                        UnitObj.report('	Focus likely larger than %d', StartPos);
                    end
                    Cont = false;
        
                case 'found'
                    if Args.Verbose
                        UnitObj.report('	Focus found.\n\n');
                    end
                    % focus likely found
                    Cont = false;
                            
                case 'cont'
                    % focus not found
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
    Result.ResTable = ResTable;
        
    % opening or creating the log file
    fileID = fopen('~/log/logfocusTel_C'+string(CameraObj.classCommand('CameraNumber'))+'_'+datestr(now,'YYYYMMDD')+'.txt','a+');
    fprintf(fileID,'\n\nFocusloop finished on '+string(datestr(now)));
    fclose(fileID);
    
    
    % search for global minimum    
    if Counter>=Args.MaxIter
        % focus not found
        Result.Status = 'Max iter reached';
        Success       = false;
        UnitObj.report('	Max iter reached.\n')
        Result.BestPos = Args.PosGuess;   % moving back to initial position
	elseif sum(ResTable(:,4))<3
        Result.Status = 'Number of good FWHM points is smaller than 3';
        Success       = false;
        UnitObj.report('	Fewer than 3 good points.\n')
        Result.BestPos = Args.PosGuess;   % moving back to initial position
        
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
                [Result.BestPos, Result.BestFWHM, adjrsquare] = fitParabola(Foc,FWHM);
                
                if adjrsquare<0.85 && length(Foc)>6
                    UnitObj.report('Bad fit. Trying to remove outliers.\n')
                    % % % outlier rejection might need some more testing % % %
                    [Result.BestPos, Result.BestFWHM, adjrsquare] = fitParabolaOutliers(Foc,FWHM,2,30)

                end
                
                plot(Result.BestPos, Result.BestFWHM, 'ro', 'MarkerFaceColor','r');
                drawnow

                UnitObj.report('   best position %d\n', Result.BestPos)
                UnitObj.report('   best FWHM %d\n', Result.BestFWHM)
                UnitObj.report('   adjusted Rsqu %d\n', adjrsquare)
                
                
                % not yet tested at night
                % always TemperatureSensors(1)? 2, returns -60
                temp1 = UnitObj.PowerSwitch{1}.classCommand('Sensors.TemperatureSensors(1)')
                temp2 = UnitObj.PowerSwitch{2}.classCommand('Sensors.TemperatureSensors(1)')
                UnitObj.report('   temperature 1 %d \n', temp1)
                UnitObj.report('   temperature 2 %d \n\n', temp2)
        
                Result.Status = 'Found.';
                Success       = true;

        
        end
        
        fprintf(fileID,'\nStatus '+Result.Status);
        if Success
            fprintf(fileID,'\nTemperature 1 '+string(temp1));
            fprintf(fileID,'\nTemperature 2 '+string(temp2));
            fprintf(fileID,'\nbest position '+string(Result.BestPos));
            fprintf(fileID,'\nbest FWHM '+string(Result.BestFWHM));
            fprintf(fileID,'\nadjusted Rsquared '+string(adjrsquare));
            fprintf(fileID,'\nsteps '+string(counter));
            fprintf(fileID,'\ngood points '+string(sum(ResTable(:,4))));
            fprintf(fileID,'\nprevious focuser pos. '+string(CurrentPos));
        end
           
    end
    hold off
    
    fprintf(fileID,'\nnew focuser position '+string(Result.BestPos));
    fclose(fileID);
    
    % go back to previous imgtype
    CameraObj.ImType = previousImgType;
    
    % restore saving image flag
    CameraObj.SaveOnDisk=CurrentSaveImage;
    
    %--- move focuser to: BacklashPos
    FocuserObj.Pos = BacklashPos;
    FocuserObj.waitFinish;
    
    %--- move focuser to best focus position: BestPos
            
    if Args.Verbose
        UnitObj.report('Moved to best position %d\n', Result.BestPos);
    end
    
    FocuserObj.Pos = Result.BestPos;
    FocuserObj.waitFinish;
    
    info = sprintf("%.2f arcsec at %.0f", Result.BestFWHM, Result.BestPos);
    
    text(Result.BestPos, 20, info) 
    saveas(gcf,'~/log/focus_plots/focusres_'+string(CameraObj.classCommand('CameraNumber'))+'_'+datestr(now,'YYYYMMDD_HH:MM:SS')+'.png') 

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

        if lowestPoint<min(FWHM(end-1:end)-1) && lowestPoint<min(FWHM(1:3)-1) && min(FWHM(3:end-2))<6       
            % minimum likely found
            Status = 'found';
        else
            % minium not found - continue
            Status = 'cont';
        end
    end
    
end
        

  

function [BestPos, BestFWHM, adjrsquare] = fitParabola(Foc,FWHM,Args)

    Args.MakePlot = true;

    % transform x-values to get small numbers
    x = (Foc-median(Foc))/100;
    
    % find starting point
    [value, ind] = min(FWHM);
    x0 = [value 2.5 x(ind)];

    % define parabola and fit
    fitfun = fittype( @(a,b,c,x) a+b*(x-c).^2);
    [fitted_curve,gof] = fit(x,FWHM,fitfun,'StartPoint',x0);
    res = coeffvalues(fitted_curve);
    BestPos = (res(3)*100)+median(Foc);
    BestFWHM = fitted_curve(res(3));
    adjrsquare = gof.adjrsquare;
    
    % Plot results
    if Args.MakePlot
        x_new = linspace(min(Foc)-50, max(Foc)+50,20)';
        x_new2 = (x_new-median(Foc))/100;

        plot(x_new, fitted_curve(x_new2), 'r');
        
    end
end


function [BestPos, BestFWHM, adjrsquare] = fitParabolaOutliers(Foc,FWHM,Nout,Ntries)

    FitRes = nan(Ntries,3);
    for Iim=1:1:Ntries
        Ind = randperm(length(Foc),length(Foc)-Nout);
        [PosTemp, FWHMTemp, adjrsquareTemp] = fitParabola(Foc(Ind),FWHM(Ind));
        FitRes(Iim,1)=PosTemp;
        FitRes(Iim,2)=FWHMTemp;
        FitRes(Iim,3)=adjrsquareTemp;
    end
    [M,I] = max(FitRes(:,3))
    
    BestPos = FitRes(I,1)
    BestFWHM = FitRes(I,2)
    adjrsquare = FitRes(I,3)
end