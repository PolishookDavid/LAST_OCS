function success=connect(Unit)
    % Connect the unitCS to all its local and remote instruments
    % Purposes:
    % 1) turn on on power of mount and cameras
    % 2) connect all instruments assigned to this unit, via SnisOCS
    
    success=false;
    try
        for i=1:numel(Unit.PowerSwitch)
            % I suspect an improbable matlab bug, because of which sometimes the
            %  configuration file is not found
            Unit.PowerSwitch{i}.Connected=true;
        end
        
        % turning explicitely on the powers
        Unit.CameraPower(:)=true;
        Unit.MountPower=true;
        
        pause(2) % a small delay to give time to the cameras to come up
        
        if isa(Unit.Mount,'obs.api.wrappers.mount')
            Unit.Mount.Connected=true;
        else
            % no mount at all
            Unit.report(['no mount defined for unit ',Unit.Id '\n'])
        end
        
        % connect to local focusers and cameras
        for i=1:numel(Unit.Camera)
            Unit.Focuser{i}.Connected=true;
            % connect the camera as last, to add a further small delay
            %  between power on of the first camera and attempt to connect
            Unit.Camera{i}.Connected=true;
        end
        
        % if no error, declare that we are connected
        Unit.Connected=true;
        success=true;
    catch
        Unit.Connected=false;
    end
end
