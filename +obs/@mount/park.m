function park(MountObj,parking)
% parks the mount, idf parking=true, unparks it if false
    if ~exist('parking','var')
        parking=true;
    end
    MountObj.lastError='';
    MountObj.MountDriverHndl.park(parking);
    MountObj.lastError=MountObj.MountDriverHndl.lastError;
end
