function UnitObj=shutdown(UnitObj)
    % complete shutdown of the Unit:
    %  - park the mount
    %  - disconnect all devices
    %  - quit spawned slaves
    %  - power off cameras and mount
    
    UnitObj.report('  parking the mount...\n')
    UnitObj.Mount.park; % this one is blocking
    
    UnitObj.report('  disconnecting devices and slave sessions...\n')
    UnitObj.disconnect;
    
    UnitObj.report('  powering off cameras and mount\n')
    UnitObj.CameraPower(:)=false;
    UnitObj.MountPower=false;

end
