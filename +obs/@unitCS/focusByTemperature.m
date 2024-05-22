function focusByTemperature(UnitObj, itel, Temp, Args)
% adjust focus if temperature has changed significantly
%
% Written by Nora, Jan 2023
% in slave window: P.focusByTemperature(1)
% in Master: for i=[1,2,3,4], P.Slave(i).Messenger.send(['P.focusByTemperature(' num2str(i) ')']); end

    arguments
        UnitObj
        itel                        %= []; % telescopes to focus. [] means all
        Temp double
        Args.TicksPerDeg            = 19.0 ;
        Args.MovementThreshold      = 30;
    end

    % Focus log legend
    Col.Camera = 1;
    Col.JD = 2;
    Col.temp1 = 3;
    %Col.temp2 = 4;
    Col.Success = 4;
    Col.BestPos = 5;
    Col.BestFWHM = 6;
    Col.BackLashOffset = 7;

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

    DeltaTemp = (Temp-FocusLog(Col.temp1));
    UnitObj.report('   temperature changed by %.1f degrees \n', DeltaTemp);
    
    NewPos = FocusLog(Col.BestPos) + DeltaTemp * Args.TicksPerDeg;
    UnitObj.report('   best focus should be at %f \n', NewPos);

    Limits     = FocuserObj.Limits;

    CurrentPos = FocuserObj.Pos;
    
    if FocusLog(Col.Success)==0
        UnitObj.report('   Focus loop did not succeed, hence not changing focus.\n\n');
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
    
    