function UnitObj=shutdown(UnitObj)
    % complete shutdown of the Unit:
    %  - park the mount
    %  - disconnect all devices
    %  - quit spawned slaves
    %  - power off cameras and mount
    
    UnitObj.Mount.park % this one is blocking
    
    UnitObj.disconnect
    
    UnitObj.CameraPower(:)=false;
    UnitObj.MountPower=false;

end
