function restoreEncoderPositionToDefault(MountObj)
    % Restore encoder  HA/Dec Zero Position Ticks to Default value
    % The default value is stored in the physical configuration
    % file

    if obs.mount.ismountDriver(MountObj.Handle)
        HAZeroPositionTicks  = MountObj.ConfigStruct.ConfigPhysical.DefaultHAZeroPositionTicks;
        DecZeroPositionTicks = MountObj.ConfigStruct.ConfigPhysical.DefaultDecZeroPositionTicks;
        MountObj.Handle.HAZeroPositionTicks = HAZeroPositionTicks;
        MountObj.Handle.DecZeroPositionTicks = DecZeroPositionTicks;
        % update config file
        MountObj.updateConfiguration(MountObj.Config,'HAZeroPositionTicks',sprintf('%9d',HAZeroPositionTicks),'ticks');
        MountObj.updateConfiguration(MountObj.Config,'DecZeroPositionTicks',sprintf('%9d',DecZeroPositionTicks),'ticks');

    else
        error('Mount must be connected for this operation');
    end

end
