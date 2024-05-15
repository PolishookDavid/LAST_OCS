function [Ready,Status]=readyToExpose(Unit, Args)
    % readyToExpose
    % Input  : - An obs.unitCS object
    %          * ...,key,val,...
    %            'Itel' - List of telescopes to check. If empty use (1:1:4).
    %                   Default is [].
    %            'Wait' - A logical indicating if to wait till the system is
    %                   ready. Default is false. Effective only if
    %                   EarlyReturn is false.
    %            'Timeout' - Time out for waiting. Default is 20 [s].
    %            'ClearMountFaults' - A logical indicating if to clear mount
    %                   faults. Default is true.
    %            'Test - A vector of 3 logicals indicating if to test [mount,
    %                   focusers, cameras].
    %                   Default is true(1,3).
    %            'GetCoolingPower' - A logical indicating if to get the
    %                   camera cooling power. Default is false.
    %            'EarlyReturn' - return with Ready=false as soon as the
    %                   first component was found not ready, without checking
    %                   further. The Status report will then be partial.
    %                   If EarlyReturn=true, 'Wait' is not honored.
    %                   Default is true.
    % Output : - A logical indicating if the requested components are ready.
    %          - A status structure.
    % Author : Eran Ofek (Apr 2022) revised Enrico Segre (May 2024)
    % Example: [ready,stat]=P.readyToExpose('Test',[0 0 1])
    %          [ready,stat]=P.readyToExpose('Test',[1 0 1],'GetCoolingPower',true);
    %          [ready,stat]=P.readyToExpose('Test',[1 0 1],'GetCoolingPower',true, 'ClearMountFaults',false);


    arguments
        Unit
        Args.Itel                        = [];
        Args.Wait (1,1) logical          = false; 
        Args.Timeout (1,1)           double  = 20;
        Args.ClearMountFaults (1,1) logical  = true;
        Args.Test    (1,3) logical           = [true, true, true];  % test: mount, focuser, camera
        Args.GetCoolingPower (1,1) logical   = false;
        Args.EarlyReturn (1,1) logical       = true;
    end
    SEC_IN_DAY = 86400;

    if isempty(Args.Itel)
        Args.Itel = 1:numel(Unit.Camera);
    end
    Ncam = numel(Args.Itel);

    Ready = false;
    SlaveFault = false;
    T0    = now;

    Status=struct('mount','','camera',{cell(1,Ncam)},...
                  'power',nan(1,Ncam),'focuser',{cell(1,Ncam)});

    CameraId = nan(1,Ncam);

    WaitCounter = 0;
    while (Args.Wait || WaitCounter==0) && ~Ready && ...
            ((now-T0)*SEC_IN_DAY)<Args.Timeout && ...
            ~(SlaveFault && Args.EarlyReturn) && ~Unit.AbortActivity
        WaitCounter = WaitCounter + 1;
        Unit.report('checking if slaves of unit %s are ready, #%d\n',Unit.Id,WaitCounter)
        for It=1:Ncam
            SlaveID = Unit.Slave(Args.Itel(It)).classCommand('Id');
            if isempty(SlaveID)
                CameraId(It) = NaN;
                SlaveFault = true;
            else
                TmpID = Unit.Camera{Args.Itel(It)}.classCommand('Id');
                % e.g., '82-1-3'
                if isempty(TmpID)
                    CameraId(It) = NaN;
                    SlaveFault = true;
                else
                    SpID = split(TmpID, '_');
                    if numel(SpID)==3
                        CameraId(It) = str2double(SpID{3});
                    else
                        % Assume no communication with slave
                        CameraId(It) = NaN;
                        SlaveFault = true;
                    end
                end
            end
            if SlaveFault && Args.EarlyReturn
                break
            end
        end

        CommSlavesOK = ~any(isnan(CameraId));

        if CommSlavesOK || ~Args.EarlyReturn
            % Slaves are responsive - check mount

            if Args.Test(1)
                Unit.report('checking if mount is in a good status\n')
                MountOK = false;
                Counter = 0;
                while ~MountOK && Counter<2
                    Counter = Counter + 1;
                    Status.mount = Unit.Mount.classCommand('Status');
                    switch lower(Status.mount)
                        case {'idle','tracking','home','aborted'}
                            MountOK = true;
                        otherwise
                            MountOK = false;

                            % try to clear faults
                            if Args.ClearMountFaults && strcmp(Status.mount,'fault')
                                Unit.Mount.clearFaults;
                            end
                    end
                end
            else
                MountOK = true;
            end

            if MountOK || ~Args.EarlyReturn
                % Mount is ok - check the focusers
                if Args.Test(2)
                    Unit.report('checking if focusers are idle\n')
                    FocuserReady = false(1, Ncam);
                    for Icam=1:1:Ncam
                        Status.focuser{Icam} = Unit.Focuser{Args.Itel(Icam)}.classCommand('Status;');
                        FocuserReady(Icam)   = strcmp(Status.focuser{Icam}, 'idle');
                    end
                else
                    FocuserReady = true(1, Ncam);
                end

                if all(FocuserReady) || ~Args.EarlyReturn
                    % focusers are ready - check camera
                    CameraReady = false(1, Ncam);
                    if Args.Test(3)
                        Unit.report('checking if cameras are idle\n')
                        for Icam=1:1:Ncam
                            Status.camera{Icam} = Unit.Camera{Args.Itel(Icam)}.classCommand('CamStatus;');
                            CameraReady(Icam)   = strcmp(Status.camera{Icam}, 'idle');
                            if CameraReady(Icam) && Args.GetCoolingPower
                                Status.power(Icam) = Unit.Camera{Args.Itel(Icam)}.classCommand('CoolingPower;');
                            end
                        end
                    else
                        CameraReady = true(1, Ncam);
                    end
                end
            end

            Ready = CommSlavesOK && MountOK && all(FocuserReady) && all(CameraReady);
        end
    end
end
    