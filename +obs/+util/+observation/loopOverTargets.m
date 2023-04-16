function loopOverTargets(Unit, Args)
    % reads in target list from file Args.CoordFileName
    % waits if no target observable
    % otherwise observe them in the provided order
    % records all obtained observations in log file
    %
    % The best way to interrupt the observations is creating the file
    % ~/abort_obs
    %
    % touch ~/abort_and_shutdown will interrupt the observations and
    % shutdown the unit
    %
    % Example: obs.util.observation.loopOverTargets(Unit,'NLoops',1,'CoordFileName','/home/ocs/target_coordinates.txt')
    %
    % written by Nora March 2023, based on pointing model script
   
    arguments
        Unit        
        %Args.ExpTime  = 20;     % default values given by
        %celestial.Targets.createList
        Args.NperVisit      = 20;
        Args.NLoops         = 1;     %
        Args.CoordFileName  = '/home/ocs/target_coordinates.txt';
        Args.MinAlt         = 30; % [deg]
        Args.ObsCoo         = [35.0407331, 30.0529838]; % [LONG, LAT]
        Args.Simulate       = false;
        Args.SimJD          = []; %current JD %2460049.205;
        %Args.DeltaJD  = 0 % fraction of the day added to JD to trick mount into thinking it's night
    end
    
    RAD = 180./pi;
    sec2day = 1./3600/24;
    

    
    Timeout=60;
    MountNumberStr = string(Unit.MountNumber);
    dt = datetime('now')-hours(6); % ensure that entire night is in same logfile
    datestring = datestr(dt, 'YYYY-mm-DD');

    if Args.Simulate,
        fprintf("\nSimulating observations! Won't move mount or take images.\n")
        if isempty(Args.SimJD),
            JD = celestial.time.julday;
            fprintf('Using current JD %.3f for simulation.\n\n',JD)
        else
            JD = Args.SimJD;
        end
    end
    
    
    % TODO: pass log dir as an argument and create dir if not present
    if Args.Simulate,
        logFileName = '~/log/sim_log_loopOverTargets_M'+MountNumberStr+'_'+datestring+'.txt';
    else
        logFileName = '~/log/log_loopOverTargets_M'+MountNumberStr+'_'+datestring+'.txt';
    end

        
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
    T=celestial.Targets.createList('RA',RA,'Dec',Dec,'TargetName',name);
    T.Data.NperVisit = ones(Ntargets,1)*Args.NperVisit;
    fprintf('Number of images per visit: %i\n', Args.NperVisit);

   
    Nloops = Args.NLoops;
    fprintf('%i fields in target list.\n\n',Ntargets)
    
        
    for Iloop=1:1:Nloops
        
        if ~Args.Simulate,
            JD = celestial.time.julday;
        end
        
        [FlagAll, Flag] = isVisible(T, JD);
        fprintf('%i targets are observable.\n\n', sum(FlagAll))

        while sum(FlagAll)==0
            
            if Args.Simulate,
                pause(1)
                JD = JD + 120*sec2day;
                simdatetime = celestial.time.get_atime(JD,35./180*pi).ISO;
                fprintf('Simulated JD: %.3f or %s\n',JD,simdatetime)
            else
                fprintf('Waiting 2 minutes.\n')
                pause(120)
                JD = celestial.time.julday; % + Args.DeltaJD;
            end
            
            [FlagAll, Flag] = isVisible(T, JD);
            fprintf('%i targets are observable.\n\n', sum(FlagAll))
        end
        
        fprintf('------------------------------------\n')
        fprintf('Starting loop %i out of %i.\n',Iloop,Nloops)
        fprintf('------------------------------------\n\n')
        
        % get observations for all targets
        for Itarget=1:1:Ntargets
            
            if exist('~/abort_obs','file')>0
                delete('~/abort_obs');
                error('user abort_obs file found');
            end
            
            if exist('~/abort_and_shutdown','file')>0
                delete('~/abort_and_shutdown');
                Unit.shutdown
                pause(30)
                error('user abort_and_shutdown file found');
            end

            
            % check whether the target is observable
            if ~Args.Simulate,
                JD = celestial.time.julday;
            end

            [FlagAll, Flag] = isVisible(T, JD);
                    
            if ~FlagAll(Itarget)
                fprintf('\nField %d is not observable.\n',Itarget)
                continue;
            end
                
                
            fprintf('\nObserving field %d out of %d - Name=%s, RA=%.2f, Dec=%.2f\n',...
                Itarget,Ntargets,T.TargetName{Itarget},T.RA(Itarget), T.Dec(Itarget));

            % slewing
            if ~Args.Simulate,
                Unit.Mount.goToTarget(T.RA(Itarget), T.Dec(Itarget));
                for IFocuser=[1,2,3,4]
                    % TODO: 'Unit' should not be hard coded
                    Unit.Slave{IFocuser}.Messenger.send(['Unit.focusByTemperature(' num2str(IFocuser) ')']); 
                end
                Unit.Mount.waitFinish;
                pause(2);
                if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
                    fprintf('Cameras not ready after timeout - abort.\n\n')
                    break;
                end                  
            end
            
            fprintf('Actual pointing: RA=%f, Dec=%f\n',Unit.Mount.RA, Unit.Mount.Dec);
            fprintf('Altitude: %f\n', Unit.Mount.Alt);
  

            % logging
            logFile = fopen(logFileName,'a+');
            fprintf(logFile,string(datestr(now, 'YYYYmmDD.HHMMSS'))+', '...
                +T.TargetName{Itarget}+', '...
                +string(Unit.Mount.RA)+', '...
                +string(Unit.Mount.Dec)+', '...
                +string(T.ExpTime(Itarget))+', '...
                +string(T.NperVisit(Itarget))+'\n');
            fclose(logFile);

            
            % taking images
            if Args.Simulate,
                JD = JD+(T.ExpTime(Itarget)*(T.NperVisit(Itarget)+1)+6)*sec2day;
                simdatetime = celestial.time.get_atime(JD,35./180*pi).ISO;
                fprintf('Simulated JD: %.3f or %s\n',JD,simdatetime)
                pause(1)
            else
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