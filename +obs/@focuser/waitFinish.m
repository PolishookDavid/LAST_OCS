function Flag = waitFinish(Focuser,timeout)
% wait until the focuser ended moving and returned to idle mode
    if ~exist('timeout','var')
        timeout=120; % seconds (that could be much or too little, depends
                     %  on what is the focuser is commanded to do)
    end
    Flag = false;
    t0=now;
    while(strcmp(Focuser.Status, 'moving')) && (now-t0)*24*3600<timeout
        pause(1);
        Focuser.report('.')
    end
    pause(1);
    if (strcmp(Focuser.Status, 'idle'))
        Focuser.report('\nMoving focuser is complete\n')
        Flag = true;
    else
        Focuser.reportError(sprintf('A problem has occurred with the focuser. Status: %s\n',...
            Focuser.Status))
    end
end
