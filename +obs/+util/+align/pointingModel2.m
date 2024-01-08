function pointingModel2(Unit, Args)
    % this one uses goToTarget2
    % Collect images for a simple pointing model
    % Example: obs.util.align.pointingModel
   
    arguments
        Unit
        Args.Nha      = 20; %30
        Args.Ndec     = 10; %15
        Args.MinAlt   = 25; % [deg]
        Args.ExpTime  = 1;     % if empty - only move without exposing
        Args.ObsCoo   = [35, 30]
        Args.Tracking logical   = true;
        Args.ClearFaults logical = false;
    end
    
    RAD = 180./pi;
    
    % make grid
        
    [TileList,~] = celestial.coo.tile_the_sky(Args.Nha, Args.Ndec);
    RADec = TileList(:,1:2)*RAD;

    [Az, Alt] = celestial.coo.radec2azalt(JD, RADec(:,1), RADec(:,2), ...
        'GeoCoo', ObsCoo, 'InUnits', 'deg', 'OutUnits', 'deg');


    RADec = RADec(Alt>MinAlt,:);
    Alt = Alt(Alt>MinAlt);
    [~, Alt] = celestial.coo.hadec2azalt(RADec(:,1), RADec(:,2), ...
        Args.ObsCoo(2)./RAD);
    
    
    Flag = Alt>(Args.MinAlt);
    RADec = RADec(Flag,:);
    Ntarget = sum(Flag);
    disp('Will observe '+string(Ntarget)+' fields.')
    
    for Itarget=1:1:Ntarget
        fprintf('Observe field %d out of %d - HA=%f, Dec=%f\n',Itarget,...
            Ntarget,RADec(Itarget,1), RADec(Itarget,2));
        if exist('~/abort','file')>0
            delete('~/abort');
            error('user abort file found');
        end
        if RADec(Itarget,2)>-50
            
            if Args.ClearFaults
                Unit.Mount.clearFaults;
            end
            %%% TODO call this instead to include all corrections except
            %%% for the pointing model itself
            [OutRA, OutDec, OutAlt, Refraction, Aux] = ...
                Unit.Mount.goToTarget2(RADec(Itarget,1), RADec(Itarget,2), ...
             	[0, 0],'ApplyDist',false);
            Aux
            
            %Unit.Mount.goTo(HADec(Itarget,1), HADec(Itarget,2), 'ha');
            Unit.Mount.waitFinish;
            if Args.Tracking
                Unit.Mount.track
            end
            pause(3);
            
            fprintf('Actual pointing: HA=%f, Dec=%f\n',Unit.Mount.HA, Unit.Mount.Dec);

            if ~isempty(Args.ExpTime)
                fprintf('call takeExposure\n');
                Unit.takeExposure([],Args.ExpTime,1,'Object','PointingModel');
                fprintf('Wait for exposure to finish\n');
            end
        
            pause(Args.ExpTime+6);
            if isempty(Args.ExpTime)
                Timeout = 60;
            else
                Timeout = Args.ExpTime+60;
            end
            if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
                disp('cameras not ready after timeout - abort')
                break;
            end
        end
    end
        
end