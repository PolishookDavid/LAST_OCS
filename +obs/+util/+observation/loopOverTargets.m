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
        Args.NperVisit = 20;
        Args.NLoops  = 1;     %
        Args.CoordFileName  = '/home/ocs/target_coordinates.txt';
        Args.MinAlt   = 30; % [deg]
        Args.ObsCoo   = [35.0407331, 30.0529838]; % [LONG, LAT]
        %Args.DeltaJD  = 0 % fraction of the day added to JD to trick mount into thinking it's night
    end
    
    RAD = 180./pi;
    
    Timeout=60;
    MountNumberStr = string(Unit.MountNumber);
    dt = datetime('now')-hours(6); % ensure that entire night is in same logfile
    datestring = datestr(dt, 'YYYY-mm-DD');

    % TODO: pass log dir as an argument and create dir if not present
    logFileName = '~/log/log_loopOverTargets_M'+MountNumberStr+'_'+datestring+'.txt';
                    
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
        
        JD = celestial.time.julday; % + Args.DeltaJD;
        [FlagAll, Flag] = isVisible(T, JD);
        fprintf('%i targets are observable.\n', sum(FlagAll))

        while sum(FlagAll)==0
            pause(120)
            JD = celestial.time.julday; % + Args.DeltaJD;
            [FlagAll, Flag] = isVisible(T, JD);
            fprintf('%i targets are observable. Waiting 2 minutes.\n', sum(FlagAll))
        end
        
        fprintf('Starting loop %i out of %i.\n\n',Iloop,Nloops)

        % get observations for all targets
        for Itarget=1:1:Ntargets
            
            if exist('~/abort_obs','file')>0
                delete('~/abort_obs');
                error('user abort_obs file found');
            end
            
            if exist('~/abort_and_shutdown','file')>0
                delete('~/abort_and_shutdown');
                Unit.shutdown
                pause(60)
                error('user abort_and_shutdown file found');
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
                    % TODO: 'Unit' should not be hard coded
                    Unit.Slave{IFocuser}.Messenger.send(['Unit.focusByTemperature(' num2str(IFocuser) ')']); 
                end
                Unit.Mount.waitFinish;
                pause(2);
            
                fprintf('Actual pointing: RA=%f, Dec=%f\n',Unit.Mount.RA, Unit.Mount.Dec);
                fprintf('Altitude: %f\n', Unit.Mount.Alt);

                if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
                    fprintf('Cameras not ready after timeout - abort.\n\n')
                    break;
                end    

                % logging
                logFile = fopen(logFileName,'a+');
                fprintf(logFile,string(datestr(now, 'YYYYmmDD.HHMMSS'))+', '...
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