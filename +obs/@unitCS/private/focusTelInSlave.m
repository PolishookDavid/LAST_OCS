function [Success, Result] = focusTelInSlave(UnitObj, itel, Args)
    % Private function. Don't it call directly. All argument validation is
    % done by its public caller focusTel(). See there.

    % Focus a single telescope, in a slave controlling the physical objects
    %   This routine can adaptively focus a single telescope, or set its
    %   focus position by a temperature-focus relation.
    
    % To abort prematurely, the master has to set (via a callback,
    % messaging on the responder) UnitObj.AbortActivity=true
    
    CameraObj  = UnitObj.Camera{itel};
    FocuserObj = UnitObj.Focuser{itel};
        
    LogDir              = '/home/ocs/log';
    PlotDir             = '/home/ocs/log/focus_plots';

    if ~isfolder(LogDir)
        mkdir(LogDir);
    end
    if ~isfolder(PlotDir)
        mkdir(PlotDir);
    end
     
    Success = false;
    % reset FocusData, creating at least itel elements (Slaves don't know
    %  how many telescopes are in the system)
    UnitObj.FocusData = repmat(obs.FocusData,1,itel);
    UnitObj.FocusData(itel).ResTable = repmat(UnitObj.FocusData(itel).ResTable(1),1,Args.MaxIter);
    UnitObj.FocusData(itel).TimeStarted=celestial.time.julday;
    
    % using the Responder for querying while the UnitMonitor is querying it
    %  is a bad idea and can lead to deadlocks (or errors, which lead to
    %  double datagramParser evaluations .... a mess).
    % temp1 = UnitObj.PowerSwitch{1}.classCommand('Sensors.TemperatureSensors(1)');
    % temp2 = UnitObj.PowerSwitch{2}.classCommand('Sensors.TemperatureSensors(1)');
    % Use instead the temperature already stored in Unit.UnitHeader
    try
        UnitObj.FocusData(itel).Temperature=...
            UnitObj.UnitHeader{strcmpi(UnitObj.UnitHeader(:,1),'MNTTEMP'),2};
    catch
    end
    
    MountNumberStr = string(UnitObj.MountNumber);
    CameraNumberStr = string(CameraObj.classCommand('CameraNumber'));
    
    %--- get Limits and current position of focuser
    Limits     = FocuserObj.Limits;

    CurrentPos = FocuserObj.Pos;
    
    % set ImgType to focus
    previousImgType = CameraObj.ImType;
    CameraObj.ImType = 'focus';
    
    % disable automatic saving (won't work in callback)
    CurrentSaveImage=CameraObj.SaveOnDisk;
    CameraObj.SaveOnDisk=false;
    % disable ComputeFWHM, so we can call it with more freedom
    CurrentComputeFWHM=CameraObj.ComputeFWHM;
    CameraObj.ComputeFWHM='omit';
    % restore them at the end
    
    % wait till camera is ready
    CameraObj.waitFinish;

    % writing UnitObj.GeneralStatus in slaves has very little use, if it is not
    %  read back by anyone
    UnitObj.GeneralStatus='checking focus at initial position';
    
    % take exposure
    % image is read with a callback - nogood when launched via messenger
    % UnitObj.takeExposure(itel,Args.ExpTime);
    CameraObj.startExposure(Args.ExpTime);
                
    % retrieve and save image explicitely, not via callbacks (in order to work also
    %  when the command is received from a messenger)
    UnitObj.abortablePause(Args.ExpTime)
    CameraObj.collectExposure;
    UnitObj.saveCurImage(itel)
                
    % get image
    Image = CameraObj.LastImage;
    [InitialFWHM, ~] = imUtil.psf.fwhm_fromBank(Image, 'HalfSize',Args.ImageHalfSize);
    CameraObj.LastImageFWHM=InitialFWHM;
    
    % don't move far away if focus already good
    if isempty(Args.SearchHalfRange)
        if (InitialFWHM<5) && isempty(Args.PosGuess)
            Args.SearchHalfRange=250;
        elseif (InitialFWHM<10) && isempty(Args.PosGuess)
            Args.SearchHalfRange=500;
        else
            Args.SearchHalfRange=750;
        end
    else
    end

    if Args.Verbose
        UnitObj.report('\n\nCurrent/Starting focus position: %d\n',CurrentPos);
        UnitObj.report('Focuser limits: %d %d\n',Limits);
        UnitObj.report('Initial Focus %d\n',InitialFWHM);
        UnitObj.report('BacklashOffset %d\n',Args.BacklashOffset);
        UnitObj.report('SearchHalfRange set to %d\n\n', Args.SearchHalfRange);
    end
    
    
    % motion direction
    MoveDir    = -sign(Args.BacklashOffset);
    
    if isempty(Args.PosGuess)
        Args.PosGuess = CurrentPos;
    end
        
    MaxPlotFWHM=26;
    
    if Args.Plot
        figure(itel);
        plot(CurrentPos, min(MaxPlotFWHM, InitialFWHM), 'co', 'MarkerFaceColor','c');
        grid on
        set(gca,'FontSize',10,'XtickLabel',string(get(gca,'Xtick')))
        hold on;
        title('Mount ' + MountNumberStr + ' Focuser '+CameraNumberStr+...
             ' - '+datestr(now,'HH:MM:SS'));
        drawnow
    end
    
    % move to backlash position
    BacklashPos = Args.PosGuess + MoveDir * Args.BacklashOffset;
        
    if BacklashPos>max(Limits)
        error('BacklashPos is above upper focuser limit');
    end
        
    % move to: BacklashPos
    FocuserObj.Pos = BacklashPos;
    FocuserObj.waitFinish;
        
    StartPos = Args.PosGuess - MoveDir * Args.SearchHalfRange;
    % move to upper range: StartPos
    FocuserObj.Pos = StartPos;
    FocuserObj.waitFinish;
        
    FocPos = StartPos;
        
    Cont     = true;
    Counter  = 0;
    while Cont && Counter<Args.MaxIter && ~UnitObj.AbortActivity
        Counter        = Counter + 1;
        
        UnitObj.FocusData(itel).Counter = Counter;
        
        UnitObj.GeneralStatus=sprintf('taking focus image #%d (%d max)',Counter,Args.MaxIter);

        % take exposure
        CameraObj.startExposure(Args.ExpTime);            
            
        % wait
        UnitObj.abortablePause(Args.ExpTime)
                
        % save image explicitely, not via callback (in order to work also
        %  when the command is received from a messenger)
        CameraObj.collectExposure;
        UnitObj.saveCurImage(itel)

        % get image
        Image = CameraObj.LastImage;
                
        % measure focus value
        [FWHM, Nstars] = imUtil.psf.fwhm_fromBank(Image, 'HalfSize',Args.ImageHalfSize);
        CameraObj.LastImageFWHM=FWHM; % so it is set even if CameraObj.ComputeFWHM='omit'
        FWHM  = min(25, FWHM); % very large values not reliable, as fwhm_fromBank doesn't work for donuts
        
        % adding outlier on purpose. delete after testing!
        %if Counter==5
        %    FWHM = 6.5;
        %end
        
        actualFocPos = FocuserObj.Pos;
        FlagGood = ~isnan(actualFocPos) & FWHM>0.5 & FWHM<Args.MaxFWHM & Nstars>Args.MinNstars;
        UnitObj.FocusData(itel).ResTable(Counter).FocPos = actualFocPos;
        UnitObj.FocusData(itel).ResTable(Counter).FWHM = FWHM;
        UnitObj.FocusData(itel).ResTable(Counter).Nstars = Nstars;
        UnitObj.FocusData(itel).ResTable(Counter).FlagGood = FlagGood;
            
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
        
        
        Step   = MoveDir * interp1(Args.FWHM_Step(:,1), Args.FWHM_Step(:,2), FWHM, 'nearest', 'extrap');
        FocPos = FocPos + Step;
        if Args.Verbose
            UnitObj.report('   Step=%d\n',Step);
        end

        % look for focus
        % consider only FWHM under 23
        if sum([UnitObj.FocusData(itel).ResTable.FWHM]<23)>4      

            FocStatus = checkForMinimum([UnitObj.FocusData(itel).ResTable(1:Counter).FWHM]);

            switch lower(FocStatus)
                case 'rising'
                    % problem
                    if Args.Verbose
                        UnitObj.report('	Rising\n');
                        UnitObj.report('	Focus likely larger than %d\n', StartPos);
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
    UnitObj.FocusData(itel).ResTable = UnitObj.FocusData(itel).ResTable(1:Counter);
    
    BacklashOffset = Args.BacklashOffset;

    % opening or creating the log file
    FName = string(LogDir)+'/logfocusTel_M'+MountNumberStr+'C'+CameraNumberStr+'_'+datestr(now,'YYYY-mm-DD')+'.txt';
    fileID = fopen(FName,'a+');
    fprintf(fileID,'\n\nFocusloop finished on '+string(datestr(now)));
    fprintf(fileID,'\nor JD '+string(celestial.time.julday));
    fprintf(fileID,'\nBacklashOffset '+string(BacklashOffset));
    %Altitude = UnitObj.Mount.Alt
    %fprintf(fileID,'\nAltitude '+string(Altitude));
   
    GoodFocus=[UnitObj.FocusData(itel).ResTable.FlagGood];
    % search for global minimum    
    if Counter>=Args.MaxIter
        % focus not found
        UnitObj.FocusData(itel).Status = 'Max iter reached';
        Success       = false;
        UnitObj.report('	Max iter reached.\n')
        UnitObj.FocusData(itel).BestPos = Args.PosGuess;   % moving back to initial position
	elseif sum(GoodFocus)<3
        UnitObj.FocusData(itel).Status = 'Number of good FWHM points is smaller than 3';
        Success       = false;
        UnitObj.report('	Fewer than 3 good points.\n')
        UnitObj.FocusData(itel).BestPos = Args.PosGuess;   % moving back to initial position
        
    else
        switch lower(FocStatus)
            case 'rising'        
                UnitObj.FocusData(itel).Status = 'Rising. Focus out of search range.';
                Success       = false;
                UnitObj.FocusData(itel).BestPos = Args.PosGuess;   % moving back to initial position
        
            case 'found'
                            
                % using only good points
                Foc  = UnitObj.FocusData(itel).ResTable(GoodFocus,1);
                FWHM = UnitObj.FocusData(itel).ResTable(GoodFocus,2);
                
        
                % Estimate minimum FWHM
                [UnitObj.FocusData(itel).BestPos, ...
                    UnitObj.FocusData(itel).BestFWHM, adjrsquare] = ...
                      fitParabola(Foc,FWHM);

                
                if adjrsquare<0.85 && length(Foc)>6
                    fprintf(fileID,'\nBad fit. Removing two outliers.');
                    UnitObj.report('Bad fit. Trying to remove outliers.\n')
                    % % % outlier rejection might need some more testing % % %
                    [UnitObj.FocusData(itel).BestPos, ...
                        UnitObj.FocusData(itel).BestFWHM, adjrsquare] = ...
                           fitParabolaOutliers(Foc,FWHM,2,30);

                end
                
                plot(UnitObj.FocusData(itel).BestPos, UnitObj.FocusData(itel).BestFWHM,...
                     'ro', 'MarkerFaceColor','r');
                drawnow

                
                if UnitObj.FocusData(itel).BestPos<min(Foc)
                    UnitObj.FocusData(itel).Status = 'Bad fit.';
                    Success       = false;
                    UnitObj.FocusData(itel).BestPos = CurrentPos;   % moving back to initial position
                    UnitObj.report('   Bad fit.\n')
                elseif UnitObj.FocusData(itel).BestPos>max(Foc)
                    UnitObj.FocusData(itel).Status = 'Bad fit.';
                    Success       = false;
                    UnitObj.FocusData(itel).BestPos = CurrentPos;   % moving back to initial position
                    UnitObj.report('   Bad fit.\n')
                else
                    UnitObj.FocusData(itel).Status = 'Found.';
                    Success       = true;
                    %UnitObj.FocusData(itel).BestPos = NaN;   % moving back to initial position
                    
                    UnitObj.report('   best position %d\n', UnitObj.FocusData(itel).BestPos)
                    UnitObj.report('   best FWHM %.2f\n', UnitObj.FocusData(itel).BestFWHM)
                    UnitObj.report('   adjusted Rsqu %.f3\n', adjrsquare)
                end
    
        end
    end
        
    temp1=UnitObj.FocusData(itel).Temperature;
    UnitObj.report('   temperature %.1f \n', temp1);
    %UnitObj.report('   temperature 2 %.1f \n\n', temp2);
    
    fprintf(fileID,'\nStatus '+string(UnitObj.FocusData(itel).Status));
    fprintf(fileID,'\nTemperature '+string(temp1));
    %fprintf(fileID,'\nTemperature 2 '+string(temp2));
    fprintf(fileID,'\nsteps '+string(Counter));
    fprintf(fileID,'\ngood points '+string(sum(GoodFocus)));
        
    if Success
        UnitObj.report('   best position %d\n', UnitObj.FocusData(itel).BestPos)
        UnitObj.report('   best FWHM %d\n', UnitObj.FocusData(itel).BestFWHM)
        UnitObj.report('   adjusted Rsqu %d\n', adjrsquare)
        
        %fprintf(fileID,'\nbest position %f', UnitObj.FocusData(itel).BestPos);
        %fprintf(fileID,'\nbest FWHM %f', UnitObj.FocusData(itel).BestFWHM);
        %fprintf(fileID,'\nadjusted Rsquared %f', adjrsquare);

        %fprintf(fileID,'\nbest position '+string(UnitObj.FocusData(itel).BestPos));
        %fprintf(fileID,'\nbest FWHM '+string(UnitObj.FocusData(itel).BestFWHM));
        %fprintf(fileID,'\nadjusted Rsquared '+string(adjrsquare));
    end
    
    Result=struct('Status',UnitObj.FocusData(itel).Status,...
                  'BestPos',UnitObj.FocusData(itel).BestPos,...
                  'BestFWHM',UnitObj.FocusData(itel).BestFWHM,...
                  'Counter',UnitObj.FocusData(itel).Counter);
           
    hold off
    
    % go back to previous imgtype
    CameraObj.ImType = previousImgType;
    
    % restore saving image and compute FWHM flags
    CameraObj.SaveOnDisk=CurrentSaveImage;
    CameraObj.ComputeFWHM=CurrentComputeFWHM;
    
    %--- move focuser to: BacklashPos
    FocuserObj.Pos = BacklashPos;
    FocuserObj.waitFinish;
    
    %--- move focuser to best focus position: BestPos
            
    if Args.Verbose
        UnitObj.report('Moved to best position %d\n', UnitObj.FocusData(itel).BestPos);
    end
    
    FocuserObj.Pos = UnitObj.FocusData(itel).BestPos;
    FocuserObj.waitFinish;
    
    % set CameraObj.LastImageFWHM to the estimated best value, even though
    %  it is stricly incorrect, because that value was never derived from a
    %  real image
    CameraObj.LastImageFWHM=UnitObj.FocusData(itel).BestFWHM;
    
    fprintf(fileID,'\nactual new focuser position '+string(FocuserObj.Pos));
    fclose(fileID);
    
    
    % computer readable log containing only most recent result. Not really
    %  useful, left as a relic. Once it was reread by
    %  unitCS.checkFocusTelSuccess(), but it makes more sense now to
    %  inspect Unit.FocusData instead. Also .focusByTemperature reads it,
    %  though
    path = pipeline.last.constructCamDir(CameraObj.classCommand('CameraNumber'), 'SubDir', 'log');
    if not(isfolder(path))
        mkdir(path);
    end
    %filename = sprintf('log_focusTel_LAST.001.%s.%02d.txt',MountNumberStr, CameraNumberStr)
    
    filename = sprintf('log_focusTel_M'+MountNumberStr+'C'+CameraNumberStr+'.txt');
    log2 = fopen(append(path,'/',filename),'w');
    fprintf(log2,CameraNumberStr+'\n');
    fprintf(log2,string(celestial.time.julday)+'\n');            
    fprintf(log2,string(temp1)+'\n');
    % fprintf(log2,string(temp2)+'\n');
    if Success
        fprintf(log2,'1\n');
        fprintf(log2,string(UnitObj.FocusData(itel).BestPos)+'\n');
        fprintf(log2,string(UnitObj.FocusData(itel).BestFWHM)+'\n');
    else
        fprintf(log2,'0\n');
        fprintf(log2,'NaN\n');
        fprintf(log2,'NaN\n');
    end
    fprintf(log2,string(BacklashOffset));
    fclose(log2);
    
    info = sprintf("%.2f arcsec at %.0f", UnitObj.FocusData(itel).BestFWHM, UnitObj.FocusData(itel).BestPos);    
    text(UnitObj.FocusData(itel).BestPos, 10, info)
    PlotName = string(PlotDir)+'/focusres_M'+MountNumberStr+'C'+CameraNumberStr+'_'+datestr(now,'YYYYmmDD_HH:MM:SS')+'.png';
    saveas(gcf,PlotName)
    
    % at this point we can set the flag, so that readers are aware that the
    %  loop completed in a way or another
    UnitObj.FocusData(itel).LoopCompleted=true;
    UnitObj.FocusData(itel).TimeEnded=celestial.time.julday;

    % restore UnitObj.AbortActivity = false, to be on the safe side
    UnitObj.AbortActivity=false;
end


% util funs
function Status = checkForMinimum(FWHM)
    %
    % requires minimum of 5 points
   
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
    [M,I] = max(FitRes(:,3));
    
    BestPos = FitRes(I,1);
    BestFWHM = FitRes(I,2);
    adjrsquare = FitRes(I,3);
end
