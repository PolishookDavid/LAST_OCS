function home(MountObj)
    % send the mount to its home position as defined by the driver

    if MountObj.IsConnected && obs.mount.ismountDriver(MountObj.Handle)
        switch lower(MountObj.Status)
            case 'park'
                MountObj.LogFile.writeLog('Can not send mount to home position while parking');
                MountObj.LastError = 'Can not send mount to home position while parking';
                if MountObj.Verbose
                    fprintf('Can not send mount to home position while parking\n');
                end
            otherwise
                MountObj.LogFile.writeLog('Slewing home')
                MountObj.Handle.home;
                % Start timer to notify when slewing is complete
                %MountObj.SlewingTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'mount-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @MountObj.callback_timer, 'ErrorFcn', 'beep');
                %start(MountObj.SlewingTimer);
        end
    else
        MountObj.LogFile.writeLog('Mount is not connected');
        MountObj.LastError = 'Mount is not connected';
        if MountObj.Verbose
            fprintf('Mount is not connected\n');
        end

    end
end
