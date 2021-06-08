function Flag=stopMotors(MountObj)
    % stop mount motors using the Handle.reset command WTF???

    MountObj.Handle.reset;
    switch lower(MountObj.Status)
        case 'disabled'
            Flag = true;
        otherwise
            Flag = false;
    end
    MountObj.LogFile.writeLog(sprintf('Mount motors stoped - sucess: %d',Flag));

end
