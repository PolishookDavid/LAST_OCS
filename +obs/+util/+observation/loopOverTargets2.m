function loopOverTargets(Unit, Args)
    % Loop over list of targets and observe them
    % program checks by itself if targets are observable
    % Ra,Dec of targets are provided in file. Default is ~/target_coordinates.txt
    % The best way to interrupt the observations is creating the file ~/abort
    %
    % Example: obs.util.observation.loopOverTargets2(Unit, 'ExpTime',5,'Nimages',1, 'NLoops',1)
    %
    % written by Nora Nov. 2022, based on pointing model script
   
    arguments
        Unit        
        %Args.ExpTime  = 20;     % default values given by
        %celestial.Targets.createList
        %Args.Nimages = 20;
        Args.NLoops  = 1;     %
        Args.CoordFileName  = '/home/ocs/target_coordinates.txt';
        Args.MinAlt   = 30; % [deg]
        Args.ObsCoo   = [35.0407331, 30.0529838]; % [LONG, LAT]
        %Args.DeltaJD  = 0 % fraction of the day added to JD to trick mount into thinking it's night
    end
    
    RAD = 180./pi;
    
    Timeout=60;
    MountNumberStr = string(Unit.MountNumber);

    % TODO: pass log dir as an argument and create dir if not present
    logFileName = '~/log/log_loopOverTargets_M'+MountNumberStr+'_'+datestr(now,'YYYY-mm-DD')+'.txt','a+';
                    
    % columns of logfile
    if ~isfile(logFileName)
        logFile = fopen(logFileName,'a+');
        fprintf(logFile,'datetime, targetname, RA, Dec, ExpTime, NImages\n');
        fclose(logFile);
    end


    % reading target coordinates from file with format name,ra,dec
    [name, RAStr, DecStr] = textread(Args.CoordFileName, '%s %s %s', 'delimiter',',');
    
    Ntargets = length(RAStr);
    RA = zeros(Ntargets, 1);
    Dec = zeros(Ntargets, 1);
    for Itarget=1:1:Ntargets,
        RA(Itarget) = str2double(RAStr{Itarget});
        Dec(Itarget) = str2double(DecStr{Itarget});
        if isnan(RA(Itarget))
            [RATemp, DecTemp, ~]=celestial.coo.convert2equatorial(RAStr{Itarget},DecStr{Itarget});
            RA(Itarget) = RATemp;
            Dec(Itarget) = DecTemp;
        end
    end
    T=celestial.Targets.createList('RA',RA,'Dec',Dec,'TargetName',name)
   
    Nloops = Args.NLoops;
    fprintf('%i fields in target list.\n\n',Ntargets)
    
    for Iloop=1:1:Nloops

        fprintf('Starting loop %i out of %i.\n\n',Iloop,Nloops)

        % get observations for all targets
        for Itarget=1:1:Ntargets
            
            if exist('~/abort','file')>0
                delete('~/abort');
                error('user abort file found');
            end
            
            % check if the target is observable
            JD = celestial.time.julday; % + Args.DeltaJD;
            [FlagAll, Flag] = isVisible(T, JD);
                    
            if ~FlagAll(Itarget)
                fprintf('Field %d is not observable.\n\n',Itarget)
            else
                
                
                fprintf('Observing field %d out of %d - Name=%s, RA=%.2f, Dec=%.2f\n',...
                    Itarget,Ntargets,T.TargetName{Itarget},T.RA(Itarget), T.Dec(Itarget));

                Unit.Mount.goToTarget(T.RA(Itarget), T.Dec(Itarget));
                for IFocuser=[1,2,3,4]
                    % TODO 'Unit' should not be hard coded
                    Unit.Slave{IFocuser}.Messenger.send(['Unit.focusByTemperature(' num2str(IFocuser) ')']); 
                end
                Unit.Mount.waitFinish;
                pause(2);
            
                fprintf('Actual pointing: RA=%f, Dec=%f\n',Unit.Mount.RA, Unit.Mount.Dec);
            
                if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
                    fprintf('Cameras not ready after timeout - abort.\n\n')
                    break;
                end    

                % logging
                logFile = fopen(logFileName,'a+');
                fprintf(logFile,string(datestr(now))+', '...
                    +T.TargetName{Itarget}+', '...
                    +string(Unit.Mount.RA)+', '...
                    +string(Unit.Mount.Dec)+', '...
                    +string(T.ExpTime(Itarget))+', '...
                    +string(T.NperVisit(Itarget))+'\n');
                fclose(logFile);

  
                Unit.takeExposure([],T.ExpTime(Itarget),T.NperVisit(Itarget));
                fprintf('Waiting for exposures to finish\n\n');
                
                pause(T.ExpTime(Itarget)*(T.NperVisit(Itarget)+1)+4);

                if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
                    fprintf('Cameras not ready after timeout - abort.\n\n')
                    break;
                end
            end    
        end
    end