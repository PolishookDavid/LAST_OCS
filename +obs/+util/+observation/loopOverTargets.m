function loopOverTargets(Unit, Args)
    % Loop over list of targets and observe them
    % program checks by itself if targets are observable
    % Ra,Dec of targets are provided in file. Default is ~/target_coordinates.txt
    % The best way to interrupt the observations is creating the file ~/abort
    %
    % Example: obs.util.observation.loopOverTargets(P, 'ExpTime',5,'Nimages',1, 'NLoops',1)
    %
    % written by Nora Nov. 2022, based on pointing model script
   
    arguments
        Unit        
        Args.ExpTime  = 20;     % if empty - only move without exposing
        Args.Nimages = 20;
        Args.NLoops  = 1;     %
        Args.CoordFileName  = '/home/ocs/target_coordinates.txt';
        Args.MinAlt   = 30; % [deg]
        Args.ObsCoo   = [35.0407331, 30.0529838] % right order? [LONG, LAT]
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
    [name, RA, Dec] = textread(Args.CoordFileName, '%s %f %f', 'delimiter',',');
    Ntargets = length(RA);
    
    Nloops = Args.NLoops;
    fprintf('%i fields in target list.\n\n',Ntargets)
    
    for Iloop=1:1:Nloops

        fprintf('Starting loop %i out of %i.\n\n',Iloop,Nloops)

        % get observations for all targets
        for Itarget=1:1:Ntargets
            
            % check if the target is observable
            JD = celestial.time.julday;
            [Flag,FlagRes] = celestial.coo.is_coordinate_ok(RA(Itarget)./RAD, Dec(Itarget)./RAD, JD, ...
                    'Lon', Unit.Mount.ObsLon./RAD, ...
                    'Lat', Unit.Mount.ObsLat./RAD, ...
                    'AltMinConst', Args.MinAlt./RAD,...
                    'AzAltConst', Unit.Mount.AzAltLimit./RAD);
        
            if ~Flag
                fprintf('Field %d is not observable.\n\n',Itarget)
            else

                if exist('~/abort','file')>0
                    delete('~/abort');
                    error('user abort file found');
                end
                
                
                fprintf('Observing field %d out of %d - Name=%s, RA=%.2f, Dec=%.2f\n',Itarget,Ntargets,name{Itarget},RA(Itarget), Dec(Itarget));

                Unit.Mount.goToTarget(RA(Itarget), Dec(Itarget));
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

                if ~isempty(Args.ExpTime)
                    % logging
                    logFile = fopen(logFileName,'a+');
                    fprintf(logFile,string(datestr(now))+', '...
                        +name(Itarget)+', '...
                        +string(Unit.Mount.RA)+', '...
                        +string(Unit.Mount.Dec)+', '...
                        +string(Args.ExpTime)+', '...
                        +string(Args.Nimages)+'\n');
                    fclose(logFile);

  
                    Unit.takeExposure([],Args.ExpTime,Args.Nimages);
                    fprintf('Waiting for exposures to finish\n\n');
                    
                end
        
                pause(Args.ExpTime*(Args.Nimages+1)+4);

                if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
                    fprintf('Cameras not ready after timeout - abort.\n\n')
                    break;
                end
            end    
        end
    end