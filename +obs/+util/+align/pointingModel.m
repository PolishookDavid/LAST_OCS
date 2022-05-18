function pointingModel(Unit, Args)
    % Collect images for a simple pointing model
    % Example: obs.util.align.pointingModel
   
    arguments
        Unit
        Args.Nha      = 20;
        Args.Ndec     = 10;
        Args.MinAlt   = 30; % [deg]
        Args.ExpTime  = 1;     % if empty - only move without exposing
        Args.ObsCoo   = [35, 30]
        Args.Tracking logical   = true;
    end
    
    RAD = 180./pi;
    
    % make grid
        
    [TileList,TileArea] = celestial.coo.tile_the_sky(Args.Nha, Args.Ndec);
    HADec = TileList(:,1:2);
    
    [Az, Alt] = celestial.coo.hadec2azalt(HADec(:,1), HADec(:,2), Args.ObsCoo(2)./RAD);
    
    % convert everything to degrees
    Az = Az*RAD;
    Alt = Alt*RAD;
    HADec = HADec*RAD;
    
    Flag = Alt>(Args.MinAlt);
    HADec = HADec(Flag,:);
    Ntarget = sum(Flag);
    disp('Will observe '+string(Ntarget)+' fields.')
    
    for Itarget=1:1:Ntarget
        fprintf('Observe field %d out of %d - HA=%f, Dec=%f\n',Itarget,Ntarget,HADec(Itarget,1), HADec(Itarget,2));
        if exist('~/abort','file')>0
            delete('~/abort');
            error('user abort file found');
        end
        if HADec(Itarget,2)>-50
            
            Unit.Mount.goTo(HADec(Itarget,1), HADec(Itarget,2), 'ha');
            Unit.Mount.waitFinish;
            Unit.Mount.track(Args.Tracking);
            pause(2);

            if ~isempty(Args.ExpTime)
                fprintf('call takeExposure\n');
                Unit.takeExposure([],Args.ExpTime,1);
                fprintf('Wait for exposure to finish\n');
            end
        
            pause(Args.ExpTime+4);
            if ~Unit.readyToExpose('Wait',true)
                disp('cameras not ready after timeout - abort')
                break;
            end
        end
    end
        
end