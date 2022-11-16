function loopOverTargets(Unit, Args)
    % Collect images for a simple pointing model
    % Example: obs.util.observation.loopOverTargets
   
    arguments
        Unit        
        Args.NLoops  = 1;     %
        Args.MinAlt   = 30; % [deg]
        Args.ExpTime  = 1;     % if empty - only move without exposing
        Args.ObsCoo   = [35, 30]
        Args.Tracking logical   = true;
        Args.ClearFaults logical = false;
    end
    
    RAD = 180./pi;
    
    if isempty(Args.ExpTime)
        Timeout = 60;
    else
        Timeout = Args.ExpTime+60;
    end
    
    RADec = [[300, 50]; [340, 70]; [320, 40]; [120, 40]];
    
    
    Nloops = Args.NLoops;
    disp('Reading in '+string(length(RADec))+' fields.')
    
    for Iloop=1:1:Nloops

        JD = celestial.time.julday;
        [Flag,FlagRes] = celestial.coo.is_coordinate_ok(RADec(:,1)./RAD, RADec(:,2)./RAD, JD, ...
                'Lon', Unit.Mount.ObsLon./RAD, ...
                'Lat', Unit.Mount.ObsLat./RAD, ...
                'AltMinConst', Unit.Mount.MinAlt./RAD,...
                'AzAltConst', Unit.Mount.AzAltLimit./RAD);
        
        RADec_observable = RADec(Flag,:);
        Ntarget = sum(Flag);
        fprintf('%d out of %d fields are observable.',Ntarget,length(RADec))
        disp('Starting loop '+string(Iloop)+'.')

        for Itarget=1:1:Ntarget
        
            fprintf('Observe field %d out of %d - RA=%f, Dec=%f\n',Itarget,Ntarget,RADec(Itarget,1), RADec(Itarget,2));
            if exist('~/abort','file')>0
                delete('~/abort');
                error('user abort file found');
            end
            if RADec_observable(Itarget,2)>-50
            

                Unit.Mount.goToTarget(RADec_observable(Itarget,1), RADec_observable(Itarget,2));
                Unit.Mount.waitFinish;
                pause(2);
            
                fprintf('Actual pointing: RA=%f, Dec=%f\n',Unit.Mount.RA, Unit.Mount.Dec);

                if ~isempty(Args.ExpTime)
                    fprintf('call takeExposure\n');
                    Unit.takeExposure([],Args.ExpTime,1);
                    fprintf('Wait for exposure to finish\n');
                end
        
                pause(Args.ExpTime+4);

                if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
                    disp('cameras not ready after timeout - abort')
                    break;
                end
            end
        end
    end