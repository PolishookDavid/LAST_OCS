function pointingModel2(Unit, Args)
    % record pointing model data using goToTarget2
    %   For calculating and writing the pointing model use:
    %   pipeline.last.pointingModel_Solve and 
    %   pipeline.last.pointingModel_Write
    % Input  : - UnitObject
    %          * ...,key,val,...
    %            see code.
    %          'TestPM' - Record a new pointing model if false. Ensure that
    %          no pointing model is loaded otherwise the header coordinates
    %          will be wrong. If true, records data with distortions
    %          according to previously calculated pointing model. Default
    %          is false.
    % Author : Nora Linn Strotjohann (Jan 2024)
    % Example: obs.util.align.pointingModel2(Unit)
    
    arguments
        Unit
        Args.Nha      = 20; %30
        Args.Ndec     = 10; %15
        Args.MinAlt   = 25; % [deg]
        Args.ExpTime  = 1;     % if empty - only move without exposing
        Args.Obs      = celestial.earth.observatoryCoo('Name','LAST');
        Args.TestPM   = false;
    end
    
    RAD = 180./pi;
    ObsCoo = [Args.Obs.Lon Args.Obs.Lat];
    
    if isempty(Args.ExpTime)
        Timeout = 60;
    else
        Timeout = Args.ExpTime + 60;
    end

    
    if Args.TestPM
        fprintf('\nRecording test images for existing pointing model.\n\n')
        ApplyDistortions = true;
        Object = 'PointingTest';
    else
        fprintf('\nRecording new pointing model. Make sure to remove the previous PM before defining the Unit object.\n\n')
        ApplyDistortions = false;
        Object = 'PointingModel';
    end
    
    % make grid    
    [TileList,~] = celestial.grid.tile_the_sky(Args.Nha, Args.Ndec);
    RADec = TileList(:,1:2)*RAD;
    JD = celestial.time.julday;

    [~, Alt] = celestial.coo.radec2azalt(JD, RADec(:,1), RADec(:,2), ...
        'GeoCoo', ObsCoo, 'InUnits', 'deg', 'OutUnits', 'deg');

    
    RADec = RADec(Alt>Args.MinAlt,:);
    Alt = Alt(Alt>Args.MinAlt);
    
    Ntarget = length(RADec(:,1));
    disp('Will observe '+string(Ntarget)+' fields.')
    
    for Itarget=1:1:Ntarget
        
        fprintf('\nObserve field %d out of %d - RA=%f, Dec=%f, Alt=%f\n', ...
            Itarget,Ntarget,RADec(Itarget,1), RADec(Itarget,2), Alt(Itarget));

        [Flag,OutRA,OutDec,Aux] = ...
            Unit.Mount.goToTarget2(RADec(Itarget,1), RADec(Itarget,2), ...
          	[0, 0], ApplyDistortions);
            
        Unit.Mount.waitFinish;
        pause(3);
            
        fprintf('Actual pointing: HA=%f, Dec=%f\n',Unit.Mount.HA, Unit.Mount.Dec);

        if ~isempty(Args.ExpTime)
            Unit.takeExposure([],Args.ExpTime,1,'Object',Object);
            fprintf('Waiting for exposures\n');
            pause(Args.ExpTime+3);
        end
        
        if ~Unit.readyToExpose('Wait',true, 'Timeout',Timeout)
            disp('cameras not ready after timeout - abort')
            break;
        end
    end
        
end