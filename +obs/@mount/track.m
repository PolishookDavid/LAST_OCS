function track(I,rate)
    if ~exist('rate','var')
        MountObj.MountDriverHndl.track(); % Driver will tarck at sidereal rate
    else
        MountObj.MountDriverHndl.track(rate);
    end
end