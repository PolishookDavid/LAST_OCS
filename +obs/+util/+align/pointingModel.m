function pointingModel(Unit, Args)
    % record pointing model data using goToTarget
    % Input  : 'Unit' - the unit object
    %          'Nha' - number of HA points used when tiling the sky
    %          'Ndec' - number of Dec points used when tiling the sky
    %          'MinAlt' - only observe positions above this altitude [deg]
    %          'ExpTime' - exposure time [s]
    %          'ObsCoo' - observatory Long Lat [deg deg]. Default [35, 30].
    %          'TestPM' - if true: test existing pointing model, Object set
    %          to TestPM (will apear in filename) and applies distortions,
    %          if false Object set to PointingModel and doesn't apply
    %          distortions - default false
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
        Args.TestPM   = false;
    end
    
    
    if ~Args.TestPM
        Object   = 'PointingModel';
        ApplyDistortion = false;
    else
        Object   = 'TestPM';
        ApplyDistortion = true;
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

        Unit.Mount.goToTarget(RA,HADec(Itarget,2),[0, 0],ApplyDistortion);
        Unit.Mount.waitFinish;

            
        fprintf('Actual pointing: HA=%.3f, Dec=%.3f\n',Unit.Mount.HA, Unit.Mount.Dec);

        if ~isempty(Args.ExpTime)
            Unit.takeExposure([],Args.ExpTime,1,'Object',Object);
            fprintf('Wait for exposure to finish\n');
        end
        
        pause(Args.ExpTime+3);

        if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
            Unit.reportError('cameras not ready after timeout - abort')
            break;
        end
    end
        
end