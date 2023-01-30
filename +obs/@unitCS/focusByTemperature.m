function [RC]=focusByTemp(UnitObj, itel, Args)
% adjust focus if temperature has changed significantly
%
% Written by Nora, Jan 2023
% in slave window: P.focusByTel(1)
% in Master: for i=[1,2] P.Slave{i}.Messenger.send(['P.focusByTemperature(' num2str(i) ')'])
% end


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
    HostName = tools.os.get_computer;
    FocusLogBaseFileName = ['log_focusTel_M',HostName(6),'C',int2str(itel),'.txt'];
    FocusLogDirFileName = [pipeline.last.constructCamDir(itel,'SubDir','log'),'/', FocusLogBaseFileName];

    if(~exist(FocusLogDirFileName, 'file'))
        fprintf('Could not find focus log.\n')
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
    UnitObj.report('   best focus should be at %i \n', NewPos);

    Limits     = FocuserObj.Limits;

    CurrentPos = FocuserObj.Pos;
    
    if FocusLog(Col.Success)==0
        error('Focus loop did not succeed.');
    elseif (NewPos>Limits(2))
        error('New positions is above upper focuser limit.');
    elseif (abs(CurrentPos-NewPos)<Args.MovementThreshold)
        UnitObj.report('   Focuser is already near default position %i \n', CurrentPos);
        
    else
        UnitObj.report('   will move focuser to %i \n', NewPos);

        % direction has to be the same as in focusTel
        BacklashPos = CurrentPos - FocusLog(Col.BackLashOffset);
        
        if BacklashPos>max(Limits)
            error('BacklashPos is above upper focuser limit');
        end
            % move to: BacklashPos
            FocuserObj.Pos = BacklashPos;
            FocuserObj.waitFinish;
    
            % move to: BacklashPos
            FocuserObj.Pos = NewPos;
            FocuserObj.waitFinish;
    end
    
    