function callback_timer(MountObj, ~, ~)
    % After slewing, check if mount is in Idle status 
    % ????? this is used currently by park, home and goto. But park and
    % home should be implemented as blocking functions in every driver,
    %  and if a goto destination check is needed, there should be other
    %  proper means

    if (~strcmp(MountObj.Status, 'slewing'))
       stop(MountObj.SlewingTimer);
       % beep
       MountObj.report('Slewing is complete')
    end

end
