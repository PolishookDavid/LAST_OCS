function pointingModel(Unit, Args)
    % record pointing model data using goToTarget
    % Input  : 'Unit' - the unit object
    %          'Nha' - number of HA points used when tiling the sky
    %          'Ndec' - number of Dec points used when tiling the sky
    %          'MinAlt' - only observe positions above this altitude [deg]
    %          'ExpTime' - exposure time [s]
    %          'ObsCoo' - observatory Long Lat [deg deg]. Default [35, 30].
    %          'Object' - string that will appear in file name. Default
    %          is "PointModel"
    %          'ApplyDistortion' - logical use existing pointing model or
    %          not. Should be false to record a new pointing model. Default 
    %          is false.
    %
    % Output : - None
    % Author : Nora Strotjohann (Jan 2024)
    % Example: obs.util.align.pointingModel(Unit)
   
    arguments
        Unit
        Args.Nha      = 20; %30
        Args.Ndec     = 10; %15
        Args.MinAlt   = 25; % [deg]
        Args.ExpTime  = 1;     % if empty - only move without exposing
        Args.Obs      = celestial.earth.observatoryCoo('Name','LAST');
        Args.Object   = 'PointingModel';
        Args.ApplyDistortion = false;
    end
    
    RAD = 180./pi;    
    
    % timeout for cameras used in readyToExpose
    if isempty(Args.ExpTime)
        Timeout = 60;
    else
        Timeout = Args.ExpTime+60;
    end
    
    % make grid
    [TileList,~] = celestial.grid.tile_the_sky(Args.Nha, Args.Ndec);
    HADec = TileList(:,1:2);

    [~, Alt] = celestial.coo.hadec2azalt(HADec(:,1), HADec(:,2), ...
        Args.Obs.Lat./RAD);
    
    
    % convert everything to degrees
    Alt = Alt*RAD;
    HADec = HADec*RAD;
    
    HADec = HADec(Alt>Args.MinAlt,:);
    Alt = Alt(Alt>Args.MinAlt);
    
    Ntarget = length(HADec(:,1));
    disp('Will observe '+string(Ntarget)+' fields.')
    
    for Itarget=1:1:Ntarget
        if exist('~/abort','file')>0
            delete('~/abort');
            error('user abort file found');
        end
        
        RA = Unit.Mount.LST - HADec(Itarget,1);
        if RA<0
            RA = RA+360;
        elseif RA>360
            RA = RA-360;
        end
        fprintf('\nObserve field %d out of %d - RA=%.3f, HA=%.3f, Dec=%.3f, Alt=%.3f\n', ...
            Itarget,Ntarget,RA, HADec(Itarget,1), HADec(Itarget,2), Alt(Itarget));

        Unit.Mount.goToTarget2(RA,HADec(Itarget,2),[0, 0],Args.ApplyDistortion);
        Unit.Mount.waitFinish;

            
        fprintf('Actual pointing: HA=%.3f, Dec=%.3f\n',Unit.Mount.HA, Unit.Mount.Dec);

        if ~isempty(Args.ExpTime)
            Unit.takeExposure([],Args.ExpTime,1,'Object',Args.Object);
            fprintf('Wait for exposure to finish\n');
        end
        
        pause(Args.ExpTime+3);

        if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
            Unit.reportError('cameras not ready after timeout - abort')
            break;
        end
    end
        
end