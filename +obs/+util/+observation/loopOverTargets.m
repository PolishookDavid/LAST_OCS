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
        Args.MinAlt   = 30; % [deg] not implemented
        Args.ObsCoo   = [35.0407331, 30.0529838] % right order? [LONG, LAT]
    end
    
    RAD = 180./pi;
    
    if isempty(Args.ExpTime)
        Timeout = 60;
    else
        Timeout = Args.ExpTime+60;
    end

    % reading target coordinates from file with format name,ra,dec
    [name, RA, Dec] = textread(Args.CoordFileName, '%s %f %f', 'delimiter',',')
    
    Nloops = Args.NLoops;
    fprintf('%i fields in target list.\n\n',length(RA))
    
    for Iloop=1:1:Nloops

        % check which of the targets are observable
        JD = celestial.time.julday;
        [Flag,FlagRes] = celestial.coo.is_coordinate_ok(RA./RAD, Dec./RAD, JD, ...
                'Lon', Unit.Mount.ObsLon./RAD, ...
                'Lat', Unit.Mount.ObsLat./RAD, ...
                'AltMinConst', Unit.Mount.MinAlt./RAD,...
                'AzAltConst', Unit.Mount.AzAltLimit./RAD);
        
        name_observable = name(Flag);
        RA_observable = RA(Flag);
        Dec_observable = Dec(Flag);
        Ntarget = sum(Flag);
        fprintf('%d out of %d fields are observable.\n',Ntarget,length(RA))
        fprintf('Starting loop %i.\n\n',Iloop)

        % get observations for all targets
        for Itarget=1:1:Ntarget
        
            fprintf('Observing field %d out of %d - Name=%s, RA=%.2f, Dec=%.2f\n',Itarget,Ntarget,name_observable{Itarget},RA_observable(Itarget), Dec_observable(Itarget));
            if exist('~/abort','file')>0
                delete('~/abort');
                error('user abort file found');
            end
            
            Unit.Mount.goToTarget(RA_observable(Itarget), Dec_observable(Itarget));
            Unit.Mount.waitFinish;
            pause(2);
            
            fprintf('Actual pointing: RA=%f, Dec=%f\n',Unit.Mount.RA, Unit.Mount.Dec);

            if ~isempty(Args.ExpTime)
                Unit.takeExposure([],Args.ExpTime,Args.Nimages);
                fprintf('Waiting for exposures to finish\n\n');
            end
        
            pause(Args.ExpTime+4);

            if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
                fprintf('Cameras not ready after timeout - abort.\n\n')
                break;
            end    
        end
    end