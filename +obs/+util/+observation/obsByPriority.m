function obsByPriority(Unit, Args)
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
    % Examples: 
    % Unit.connect
    %
    % % run script in simulation mode for current JD: it will not move the 
    %mount of expose, but write which targets it will observe at what time
    % obs.util.observation.obsByPriority(Unit,'Simulate',true,'CoordFileName','/home/ocs/targetlists/target_coordinates.txt')
    %
    % % run script in simulation mode for custom JD for testing or planning
    % during the day
    % obs.util.observation.obsByPriority(Unit,'Simulate',true,'SimJD',2460049.205,'CoordFileName','/home/ocs/targetlists/target_coordinates.txt')
    %
    % % loop twice over target list and get 40 imgs per visit for each 
    % observable target
    % obs.util.observation.obsByPriority(Unit,'NperVisit',40,'CoordFileName','/home/ocs/targetlists/target_coordinates.txt')
    % obs.util.observation.obsByPriority(Unit,'CoordFileName','/home/ocs/targetlists/target_coordinates.txt')
    %
    % Use the Nmounts option to divide the target list among x mounts.
    % Modulo specifies which fields each mount will observe.
    % obs.util.observation.obsByPriority(Unit,'CoordFileName','/home/ocs/targetlists/target_coordinates.txt','NMounts',3,'Modulo',1)
    % will split the target list into a third and this mount will only
    % observe fields with mod(Index, 1), e.g. fields: 1, 4, 7, 10 etc.
    %
    % written by Nora May 2023, based on loopOverTargets script
   
    arguments
        Unit        
        %Args.ExpTime  = 20;     % default values given by
        %celestial.Targets.createList
        Args.NperVisit      = 20;
        Args.CoordFileName  = '/home/ocs/targetlists/target_coordinates.txt';
        Args.MinAlt         = 30; % [deg]
        Args.ObsCoo         = [35.0407331, 30.0529838]; % [LONG, LAT]
        Args.Simulate       = false;
        Args.SimJD          = []; %default is current JD %2460049.205;
        Args.MinVisibilityTime = 0.01; %days; stop observing target 15min before it is no longer visible
        Args.CadenceMethod = 'highestsetting';
        Args.Nmounts = 1;
        Args.Modulo = 0;
    end
    
    RAD = 180./pi;
    sec2day = 1./3600/24;
    

    
    Timeout=60;
    MountNumberStr = string(Unit.MountNumber);
    dt = datetime('now')-hours(6); % ensure that entire night is in same logfile
    datestring = datestr(dt, 'YYYY-mm-DD');

    if Args.Simulate
        fprintf("\nSimulating observations! Won't move mount or take images.\n")
        if isempty(Args.SimJD)
            JD = celestial.time.julday;
            fprintf('Using current JD %.3f for simulation.\n\n',JD)
        else
            JD = Args.SimJD;
        end
    end
    
    
    % TODO: pass log dir as an argument and create dir if not present
    if Args.Simulate
        % will overwrite logfile if in simulation mode
        logFileName = '~/log/sim_log_obsByPriority_M'+MountNumberStr+'.txt';
        obsFileName = '~/log/sim_obsPrio_M'+MountNumberStr;
    else
        % will create daily logfile if in observation mode and append all
        % observations
        logFileName = '~/log/log_obsByPriority_M'+MountNumberStr+'_'+datestring+'.txt';
        obsFileName = '~/log/obsPrio_M'+MountNumberStr+'_'+datestring;
    end

        
    % columns of logfile
    if ~isfile(logFileName) || Args.Simulate
        logFile = fopen(logFileName,'w+');
        fprintf(logFile,'datetime, obsJD, targetname, RA, Dec, ExpTime, NImages\n');
        fclose(logFile);
    end
    
    T = convertCSV2TargetObject(Args.CoordFileName, Args.NperVisit);    
    
    fprintf('%i fields in target list.\n\n',length(T.Data.RA))
    
    mask_mount = (mod(T.Data.Index, Args.Nmounts) == Args.Modulo);
    
    fprintf('Dividing target list among %i mounts. This mount will observe fields with modulo %i.',Args.Nmounts, Args.Modulo)

    T.Data = T.Data(mask_mount,:);
    Ntargets = length(T.Data.RA);
    fprintf('%i fields remaining.\n\n',Ntargets)
       
    while true
        
        if ~Args.Simulate
            JD = celestial.time.julday;
        end
        
        [FlagAll, Flag] = isVisible(T, JD,'MinVisibilityTime',Args.MinVisibilityTime);
        %fprintf('%i targets are observable.\n\n', sum(FlagAll))
        NeedObs = T.Data.MaxNobs>T.Data.GlobalCounter;
            
        fprintf('\n%i targets need more observations.\n', sum(NeedObs))
        fprintf('%i of them observable now.\n\n', sum(NeedObs&FlagAll))
            
        % wait, if no targets observable
        while sum(NeedObs&FlagAll)==0
            
            if Args.Simulate
                pause(1)
                JD = JD + 120*sec2day;
                simdatetime = celestial.time.get_atime(JD,35./180*pi).ISO;
                fprintf('Simulated JD: %.3f or %s\n',JD,simdatetime)
            else
                fprintf('Waiting 2 minutes.\n')
                pause(120)
                JD = celestial.time.julday; % + Args.DeltaJD;
            end
            
            [FlagAll, Flag] = isVisible(T, JD,'MinVisibilityTime',Args.MinVisibilityTime);         
            %fprintf('%i targets are observable.\n', sum(FlagAll))
            NeedObs = T.Data.MaxNobs>T.Data.GlobalCounter;
            
            fprintf('%i targets need more observations.\n', sum(NeedObs))
            fprintf('%i of them observable now.\n\n', sum(NeedObs&FlagAll))

            % check if end script or shutdown mount
            checkAbortFile(Unit, JD);
            
        end
        
        % check if end script or shutdown mount or sunrise
        checkAbortFile(Unit, JD);
            
            
        % check whether the target is observable
        if ~Args.Simulate
            JD = celestial.time.julday;
        end
        
        [~,PP,IndPrio]=T.calcPriority(JD,Args.CadenceMethod);
        
        if PP(IndPrio) <= 0
            fprintf('Highest priority is zero. Waiting two minutes.\n')
            
            if Args.Simulate
                pause(1)
                JD = JD + 120*sec2day;
            else
                pause(120)
            end
            continue
        end
                
        fprintf('\nObserving field %d out of %d - Name=%s, RA=%.2f, Dec=%.2f\n',...
            IndPrio,Ntargets,T.TargetName{IndPrio},T.RA(IndPrio), T.Dec(IndPrio));

        % slewing
        if ~Args.Simulate
            Unit.Mount.goToTarget(T.RA(IndPrio), T.Dec(IndPrio));
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
        fprintf('MountAltitude: %f\n', Unit.Mount.Alt);
  
        [Az, Alt] = T.azalt(JD);
        fprintf('Target Altitude: %f\n', Alt(IndPrio));
        fprintf('Observed %i out of %i. Obtaining %i more images.\n',T.GlobalCounter(IndPrio),T.MaxNobs(IndPrio),T.NperVisit(IndPrio))

        % logging
        obsJD = JD;
        logFile = fopen(logFileName,'a+');
        fprintf(logFile,string(datestr(now, 'YYYYmmDD.HHMMSS'))+', '...
                +string(obsJD)+', '...
                +T.TargetName{IndPrio}+', '...
                +string(Unit.Mount.RA)+', '...
                +string(Unit.Mount.Dec)+', '...
                +string(T.ExpTime(IndPrio))+', '...
                +string(T.NperVisit(IndPrio))+'\n');
        fclose(logFile);

            
        % taking images
        if Args.Simulate
            JD = JD+(T.ExpTime(IndPrio)*(T.NperVisit(IndPrio)+1)+6)*sec2day;
            simdatetime = celestial.time.get_atime(JD,35./180*pi).ISO;
            fprintf('Simulated JD: %.3f or %s\n',JD,simdatetime)
            pause(1)
        else
            Unit.takeExposure([],T.ExpTime(IndPrio),T.NperVisit(IndPrio));
            fprintf('Waiting for exposures to finish\n\n');
                
            pause(T.ExpTime(IndPrio)*(T.NperVisit(IndPrio)+1)+4);

            if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
               fprintf('Cameras not ready after timeout - abort.\n\n')
               break;
            end
        end
            
        % save Target table after successful observations
        T.Data.GlobalCounter(IndPrio) = T.Data.GlobalCounter(IndPrio)+T.NperVisit(IndPrio);
        T.Data.NightCounter(IndPrio) = T.Data.NightCounter(IndPrio)+T.NperVisit(IndPrio);
        T.Data.LastJD(IndPrio) = obsJD;
        T.write(obsFileName+'.mat')
        writetable(T.Data,obsFileName+'.txt','Delimiter',',')
           
    end
end
    
    


function Result = convertCSV2TargetObject(filename,NperVisit)


    targetKeys = {'RA','Dec','Index','TargetName','DeltaRA','DeltaDec', ...
        'ExpTime', 'NperVisit','MaxNobs','LastJD','GlobalCounter',...
        'NightCounter','Priority'};
    dataTypes = {'char','char','double','char','double','double',...
        'double','double','double','double','double',...
        'double','double'};
    defaultValues = {0, 0, 0, 'target', 0, 0, ...
        20, 20, Inf, 0, 0, ...
        0,1};
    
    dataTypeDict = containers.Map(targetKeys,dataTypes);
    defaultDict = containers.Map(targetKeys,defaultValues);

    opts = detectImportOptions(filename);
    
    % read only columns that fit Target class
    opts.SelectedVariableNames=opts.VariableNames(ismember(opts.VariableNames,targetKeys));
    
    
    % provide correct data types
    for Icolumn=1:1:length(opts.SelectedVariableNames)
        ColName = string(opts.SelectedVariableNames(Icolumn));
        ColIndex = find(opts.VariableNames==ColName);
        opts.VariableTypes(ColIndex)={dataTypeDict(ColName)};
    end

    
    % list rows that do not fit Target class convention
    SkippedCols = opts.VariableNames(~ismember(opts.VariableNames, opts.SelectedVariableNames));
    if ~isempty(SkippedCols)
        fprintf('\nThe following columns are unknown. Skipping them.\n')
        fprintf(1, '%s \t', SkippedCols{:})
        fprintf('\n\n')
    end
    
    % check if RA and Dec provided
    if ~ismember('RA',opts.SelectedVariableNames) || ~ismember('Dec',opts.SelectedVariableNames)
        fprintf('\n\nCannot read target list: RA or Dec missing.\n\n')
        Result = celestial.Targets;
        return
    end

    % read in relevant columns from table
    tbl = readtable(filename, opts);
    
    % convert RA and Dec to degrees
    Ntargets = height(tbl);
    RA = zeros(Ntargets, 1);
    Dec = zeros(Ntargets, 1);
    for Itarget=1:1:Ntargets
        RA(Itarget) = str2double(tbl.RA{Itarget});
        Dec(Itarget) = str2double(tbl.Dec{Itarget});
        if isnan(RA(Itarget))
            [RATemp, DecTemp, ~]=celestial.coo.convert2equatorial(tbl.RA{Itarget},tbl.Dec{Itarget});
            RA(Itarget) = RATemp;
            Dec(Itarget) = DecTemp;
        end
    end
    
    Cols  = targetKeys;
    Ncols = numel(Cols);

    % loop over columns and assign default or provided value
    Result = celestial.Targets;
    for Icol=1:1:Ncols
        if string(Cols{Icol})=='RA'
            Result.Data.RA = RA;
            
        elseif string(Cols{Icol})=='Dec'
            Result.Data.Dec = Dec;
            
        elseif ismember(Cols{Icol},tbl.Properties.VariableNames)
            Result.Data.(Cols{Icol}) = tbl.(Cols{Icol});
            
        else
            Result.Data.(Cols{Icol}) = ones(Ntargets,1)*defaultDict(Cols{Icol});
        end
    end
    
    
    if ~ismember('Index',tbl.Properties.VariableNames)
        Result.Data.Index = (1:1:Ntargets).';
    end
    
    if ~ismember('TargetName',tbl.Properties.VariableNames)
        Result.Data.TargetName = celestial.Targets.radec2name(RA, Dec);
    end
    
    if ~ismember('NperVisit',tbl.Properties.VariableNames)
        Result.Data.NperVisit = ones(Ntargets,1)*NperVisit;
        fprintf('Number of images per visit: %i\n', NperVisit)
    end
    
    %Result
    %Result.Data
    
end



function checkAbortFile(Unit, JD)

    Sun = celestial.SolarSys.get_sun(JD,[35 31]./(180./pi));
        
    if (Sun.Alt*180./pi)>-7
        error('The Sun is rising. \n\n')
    end 
        
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
end