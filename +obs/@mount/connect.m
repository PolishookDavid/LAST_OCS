function MountObj=connect(MountObj)
% connect to a focus motor on the specified Port, try all ports if
%  Port omitted
    MountObj.MountDriverHndl.connect
    MountObj.lastError = MountObj.MountDriverHndl.lastError
    MountObj.Port = MountObj.MountDriverHndl.Port;
end
