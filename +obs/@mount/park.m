function park(MountObj,ParkState)
    % Park the mount
    % Input  : - True for parking, false for unparking.
    %            Default is true;

    if nargin<2
        ParkState = true;
    end

    if MountObj.IsConnected && obs.mount.ismountDriver(MountObj.Handle)
        MountObj.LogFile.writeLog(sprintf('Call parking = %d',ParkState));

        % Need to check there is no problem with MinAlt
        MountObj.Handle.park(ParkState);

        % Start timer to notify when slewing is complete
        MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
        start(MountObj.SlewingTimer);
    else
        MountObj.LogFile.writeLog('Mount is not connected');
        MountObj.LastError = 'Mount is not connected';
        if MountObj.Verbose
            fprintf('Mount is not connected\n');
        end

    end
end
