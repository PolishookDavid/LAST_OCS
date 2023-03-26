function focusByTemperature(UnitObj, itel, Args)
% adjust focus if temperature has changed significantly
%
% Written by Nora, Jan 2023
% in slave window: P.focusByTemperature(1)
% in Master: for i=[1,2,3,4], P.Slave{i}.Messenger.send(['P.focusByTemperature(' num2str(i) ')']); end


    arguments
        UnitObj
        itel                        %= []; % telescopes to focus. [] means all
        Args.TicksPerDeg            = 19.0 ;
        Args.MovementThreshold      = 30;
    end


    % Focus log legend
    Col.Camera = 1;
    Col.JD = 2;
    Col.temp1 = 3;
    Col.temp2 = 4;
    Col.Success = 5;
    Col.BestPos = 6;
    Col.BestFWHM = 7;
    Col.BackLashOffset = 8;

    FocuserObj = UnitObj.Focuser{itel};
    FocusLogBaseFileName = ['log_focusTel_M',int2str(UnitObj.MountNumber),'C',int2str(itel),'.txt'];
    FocusLogDirFileName = [pipeline.last.constructCamDir(itel,'SubDir','log'),'/', FocusLogBaseFileName];

    if(~exist(FocusLogDirFileName, 'file'))
        fprintf('Could not find focus log with the name:\n')
        fprintf(FocusLogDirFileName)
        fprintf('\n')
        return
    else
        FocusLog = load(FocusLogDirFileName);
    end

    temp1 = UnitObj.PowerSwitch{1}.classCommand('Sensors.TemperatureSensors(1)');
    temp2 = UnitObj.PowerSwitch{2}.classCommand('Sensors.TemperatureSensors(1)');
    UnitObj.report('   temperature 1 %.1f \n', temp1);
    UnitObj.report('   temperature 2 %.1f \n', temp2);
    
    DeltaTemp = ((temp1-FocusLog(Col.temp1))+(temp2-FocusLog(Col.temp2)))*0.5;
    UnitObj.report('   temperature increased by %.1f degrees \n', DeltaTemp);
    
    NewPos = FocusLog(Col.BestPos) + DeltaTemp * Args.TicksPerDeg;
    UnitObj.report('   best focus should be at %f \n', NewPos);

    Limits     = FocuserObj.Limits;

    CurrentPos = FocuserObj.Pos;
    
    if FocusLog(Col.Success)==0
        UnitObj.report('   Focus loop did not succeed.\n\n');
    elseif (NewPos>Limits(2))
        UnitObj.report('   New position is above upper focuser limit.\n\n');
    elseif (abs(CurrentPos-NewPos)<Args.MovementThreshold)
        UnitObj.report('   No change required - focuser is already near default position %d \n\n', CurrentPos);
        
    else
        UnitObj.report('   will move focuser to %i \n\n', NewPos);

        % direction has to be the same as in focusTel
        BacklashPos = CurrentPos - FocusLog(Col.BackLashOffset);
        
        if BacklashPos>max(Limits)
            UnitObj.report('   BacklashPos is above upper focuser limit.\n\n');
        end
            % move to: BacklashPos
            FocuserObj.Pos = BacklashPos;
            FocuserObj.waitFinish;
    
            % move to: BacklashPos
            FocuserObj.Pos = NewPos;
            FocuserObj.waitFinish;
    end
    
    