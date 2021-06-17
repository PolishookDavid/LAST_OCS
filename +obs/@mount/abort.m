function abort(MountObj)
    % emergency stop
    MountObj.report('Aborting mount movement\n')

    % Stop the mount motion through the driver object
    try
        MountObj.Handle.abort;
    catch
        MountObj.reportError('Mount handle cannot abort')
    end
    % Delete the slewing timer
    delete(MountObj.SlewingTimer);
end
