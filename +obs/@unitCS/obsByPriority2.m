function obsByPriority2(Unit, Args)
    % reads in target list from file Args.CoordFileName
    % waits if no target observable
    % otherwise observe them in the provided order
    % records all obtained observations in log file
    %
    % The best way to interrupt the observations is creating the file
    %  ~/abort_obs, or to set with a callback the hidden property
    %  Unit.AbortActivity=true
    %
    % touch ~/abort_and_shutdown will interrupt the observations and
    %  shutdown the unit
    %
    % Examples: 
    %   Unit.connect
    %
    % % run script in simulation mode for current JD: it will not move the 
    % mount or expose, but write which targets it will observe at what time
    %  Unit.obsByPriority('Simulate',true,'CoordFileName','/home/ocs/targetlists/target_coordinates.txt')
    %
    % % run script in simulation mode for custom JD for testing or planning
    % during the day
    %   Unit.obsByPriority('Simulate',true,'SimJD',2460049.205,'CoordFileName','/home/ocs/targetlists/target_coordinates.txt')
    %
    % % loop twice over target list and get 40 imgs per visit for each 
    % observable target
    %   Unit.obsByPriority('NperVisit',40,'CoordFileName','/home/ocs/targetlists/target_coordinates.txt')
    %   Unit.obsByPriority('CoordFileName','/home/ocs/targetlists/target_coordinates.txt')
    %
    % Use the Nmounts option to divide the target list among x mounts.
    % Modulo specifies which fields each mount will observe.
    %   Unit.obsByPriority('CoordFileName','/home/ocs/targetlists/target_coordinates.txt','NMounts',3,'Modulo',1)
    % will split the target list into a third and this mount will only
    % observe fields with mod(Index, 1), e.g. fields: 1, 4, 7, 10 etc.
    %
    % written by Nora May 2023, based on loopOverTargets script
    % transition to gledmagicwater by Enrico, May 2024
    % Originally in obs.util.observation, promoting it (temporarily?) to an
    %  unitCS method
   
    % self note for messenger passing of targets: flatten-unflatten like
    %   TData=struct2table(jsondecode(jsonencode(T.Data(1,:))))
    % from superunit:
    %
    % S.send(sprintf("TData=struct2table(jsondecode('%s'));",jsonencode(T.Data(1:4,:))))
    % S.send("Unit.obsByPriority2('Simulate',true,'TargetData',TData)")
    
    arguments
        Unit        
        Args.Itel           = []; % telescopes to use
        Args.CoordFileName  = '/home/ocs/targetlists/target_coordinates.txt';
        Args.TargetData     = []; % if nonempty, a celestial.Targets.Data.table instead of reading the file
        Args.MinAlt         = 30; % [deg]
        Args.ObsCoo         = [35.0407331, 30.0529838]; % [LONG, LAT]
        Args.Simulate       = false;
        Args.SimJD          = []; %default is current JD %2460049.205;
        Args.MinVisibilityTime = 0.01; %days; stop observing target 15min before it is no longer visible
        Args.CadenceMethod  {mustBeMember(Args.CadenceMethod,{'cycle','predefined','highestsetting'})}= 'cycle'; % 'predefined', 'highestsetting', 'cycle'
        Args.Nmounts        = 1;
        Args.Modulo         = 0;
        Args.Shutdown       = true; % set to false when testing during the day
    end
    
    if isempty(Args.Itel)
        Args.Itel = (1:numel(Unit.Camera));
    end
        
    RAD = 180./pi;
    sec2day = 1./3600/24;
    
    UnitName=inputname(1);
    
    Unit.GeneralStatus='starting observation script';
    
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
    
    if isempty(Args.TargetData)
        T = obs.util.observation.convertCSV2TargetObject(Args.CoordFileName);
    else
        T=celestial.Targets;
        T.Data=Args.TargetData;
    end
    
    % disable bug in Targets.isVisible which can't deal with negative HA,
    % remove line ones that bug is fixed
    T.VisibilityArgs.HALimit=400;
    
    fprintf('%i fields in target list.\n\n',length(T.Data.RA))
    
    mask_mount = (mod(T.Data.Index, Args.Nmounts) == Args.Modulo);
    
    fprintf('Dividing target list among %i mounts. This mount will observe fields with modulo %i.\n',Args.Nmounts, Args.Modulo)

    T.Data = T.Data(mask_mount,:);
    Ntargets = length(T.Data.RA);
    fprintf('%i fields remaining.\n\n',Ntargets)
    
    for I=Args.Itel
        Unit.Camera{I}.classCommand('SaveOnDisk=1;'); % save images on all cameras
    end
    
    OperateBool = true;
    
    while OperateBool && ~Unit.AbortActivity
        
        if ~Args.Simulate
            JD = celestial.time.julday;
        end
        
        [FlagAll, Flag] = isVisible(T, JD,'MinVisibilityTime',Args.MinVisibilityTime);
        %fprintf('%i targets are observable.\n\n', sum(FlagAll))
        NeedObs = T.Data.MaxNobs>T.Data.GlobalCounter;
            
        fprintf('\n%i targets need more observations.\n', sum(NeedObs))
        fprintf('%i of them observable now.\n\n', sum(NeedObs&FlagAll))
            
        % wait, if no targets observable
        while (sum(NeedObs&FlagAll) == 0) && OperateBool && ~Unit.AbortActivity
            
            if ~Args.Simulate
                % check if end script or shutdown mount
                OperateBool = checkAbortFile(Unit, JD, Args.Shutdown);
                if ~OperateBool || Unit.AbortActivity
                    break
                end
            end
                       
            Unit.GeneralStatus='No targets currently observable, waiting';
            
            if Args.Simulate
                pause(1)
                JD = JD + 120*sec2day;
                simdatetime = celestial.time.get_atime(JD,35./180*pi).ISO;
                fprintf('Simulated JD: %.3f or %s\n',JD,simdatetime)
            else
                fprintf('Waiting 2 minutes.\n')
                pause(120)
                JD = celestial.time.julday; % + Args.DeltaJD;
                Unit.Mount.home; % avoid tracking when there are not targets
            end
            
            [FlagAll, Flag] = isVisible(T, JD,'MinVisibilityTime',Args.MinVisibilityTime);         
            %fprintf('%i targets are observable.\n', sum(FlagAll))
            NeedObs = T.Data.MaxNobs>T.Data.GlobalCounter;
            
            fprintf('%i targets need more observations.\n', sum(NeedObs))
            fprintf('%i of them observable now.\n\n', sum(NeedObs&FlagAll))
            
        end
        
        if ~OperateBool || Unit.AbortActivity
            break
        end          
        
        if ~Args.Simulate
            % check if end script or shutdown mount or sunrise
            OperateBool = checkAbortFile(Unit, JD, Args.Shutdown);
            if ~OperateBool || Unit.AbortActivity
                break
            end            
        end

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
                Unit.abortablePause(120)
            end
            continue
        end
                
        msg=sprintf('\nObserving field %d out of %d - Name=%s, RA=%.2f, Dec=%.2f\n',...
            IndPrio,Ntargets,T.TargetName{IndPrio},T.RA(IndPrio), T.Dec(IndPrio));
        fprintf(msg)
        Unit.GeneralStatus=sprintf('Observing field #%d/%d: "%s", (%.2f,%.2f)',...
            IndPrio,Ntargets,T.TargetName{IndPrio},T.RA(IndPrio), T.Dec(IndPrio));


        % slewing
        if ~Args.Simulate
            Unit.Mount.goToTarget(T.RA(IndPrio), T.Dec(IndPrio));
            
            temp=Unit.Temperature;
            Temp=mean(temp(temp>-30)); % the pswitch says -60 for no sensor         
            fprintf('\nTemperature %.1f deg.\n', Temp)
            
            for IFocuser=Args.Itel
                Unit.Slave(IFocuser).Messenger.send(...
                    sprintf('%s.focusByTemperature(%d,%.2f);',UnitName,IFocuser,Temp));
                           
                if Temp>35
                    Unit.Camera{IFocuser}.classCommand('Temperature=5;');
                elseif Temp>30
                    Unit.Camera{IFocuser}.classCommand('Temperature=0;');
                %elseif Temp>25
                %    Unit.Camera{IFocuser}.classCommand('Temperature=0;')
                else
                    Unit.Camera{IFocuser}.classCommand('Temperature=-5;');
                end
            end                

            Unit.Mount.waitFinish;
            Unit.abortablePause(2);
            if ~Unit.readyToExpose('Itel',Args.Itel,'Wait',true, 'Timeout',Timeout)
                fprintf('Cameras not ready after timeout - abort.\n\n')
                Unit.GeneralStatus='Cameras not ready after timeout - abort';
                break;
            end
        end

            
        fprintf('Actual pointing: RA=%f, Dec=%f\n',Unit.Mount.RA, Unit.Mount.Dec);
        fprintf('MountAltitude: %f\n', Unit.Mount.Alt);
  
        [Az, Alt] = T.azalt(JD);
        fprintf('Target Altitude: %f\n', Alt(IndPrio));

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
            %char(T.TargetName(IndPrio))
            Unit.takeExposure(Args.Itel,T.ExpTime(IndPrio),T.NperVisit(IndPrio),'Object',char(T.TargetName(IndPrio)));
            fprintf('Waiting for exposures to finish\n\n');
                
            %Unit.abortablePause(T.ExpTime(IndPrio)*(T.NperVisit(IndPrio)+1)+4);
            tstart=now;
            while (now-tstart)*86400 < (T.ExpTime(IndPrio)*(T.NperVisit(IndPrio)+1)+4) ...
                    && ~Unit.AbortActivity
                % TODO - counter compares # of frames from all cameras
                T.Data.GlobalCounter(IndPrio)=Unit.Camera{Args.Itel(1)}.classCommand('ProgressiveFrame');
                fprintf('Observed %i out of %i. Obtaining %i more images.\n',...
                    T.GlobalCounter(IndPrio),T.MaxNobs(IndPrio),T.NperVisit(IndPrio))
                % TODO out of how many? x Visit, x Night, global? 
                Unit.abortablePause(T.ExpTime(IndPrio));
            end

            if ~Unit.readyToExpose('Itel',Args.Itel,'Wait',true, 'Timeout',Timeout)
               fprintf('Cameras not ready after timeout - abort.\n\n')
               break;
            end
            
            if Unit.AbortActivity
                % send .abort to all cameras
                for i=Args.Itel
                    Unit.Camera{i}.classCommand('abort');
                end
            end
        end
            
        % save Target table after successful observations
        T.Data.GlobalCounter(IndPrio) = T.Data.GlobalCounter(IndPrio)+T.NperVisit(IndPrio);
        T.Data.NightCounter(IndPrio) = T.Data.NightCounter(IndPrio)+T.NperVisit(IndPrio);
        T.Data.LastJD(IndPrio) = obsJD;
        T.write(obsFileName+'.mat')
        writetable(T.Data,obsFileName+'.txt','Delimiter',',')
          
    end
    
    fprintf('\nObservations terminated\n');
    Unit.GeneralStatus='Observations terminated';
end


function OperateBool = checkAbortFile(Unit, JD, Shutdown)

    OperateBool = true;
    
    if Unit.AbortActivity
        % in most cases I also check indepenently, here for good
        OperateBool=false;
        return
    end

    Sun = celestial.SolarSys.get_sun(JD,[35 31]./(180./pi));
    modulo_jd = mod(JD,1); % this is to avoid shutting down when starting observations in the evening
    
    if ((Sun.Alt*180/pi)>-11.5)
        fprintf('\nThe Sun is too high.\n')
        Unit.GeneralStatus='Sun too high for observation';
        if Shutdown && (modulo_jd>0.5) && (modulo_jd<0.75)    % automatic shutdown will only happen in the morning
            fprintf('Shutting down the mount.\n')
            Unit.shutdown
            Unit.abortablePause(20)
            fprintf('shutdown because Sun too high. \n');
            OperateBool = false;
            return
        else
            fprintf('Automatic shutdown disabled!! Press CTRL+C and run Unit.shutdown to shutdown the mount.\n')
        end
        %error('The Sun is rising. Shutting down the mount. \n\n')
    end 
        
    if exist('~/abort_obs','file')>0
        delete('~/abort_obs');
        fprintf('user abort_obs file found');
        OperateBool = false;
        return
    end
    
    if exist('~/abort_and_shutdown','file')>0
        delete('~/abort_and_shutdown');
        Unit.shutdown
        pause(30)
        fprintf('user abort_and_shutdown file found');
        OperateBool = false;
        return
    end
end