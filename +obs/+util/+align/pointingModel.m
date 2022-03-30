function pointingModel(Unit, Args)
    %
    % Example: obs.util.align.pointingModel
   
    arguments
        Unit
        Args.Nha      = 20;
        Args.Ndec     = 10;
        Args.MinAlt   = 30; % [deg]
        Args.ObsCoo   = [35, 30]
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
        Unit.Mount.goTo(HADec(Itarget,1), HADec(Itarget,2), 'ha');
        Unit.Mount.waitFinish;
        Unit.Mount.track;
        pause(2);
        
        Unit.takeExposure([],1,1);
        
        pause(1);
        while ~Unit.readyToExpose
            pause(1);
        end
    end
        
end