function MountObj=connect(MountObj,Port)
% connect to a focus motor on the specified Port, try all ports if
%  Port omitted
    MountObj.MountDriverHndl.connect(Port)
    MountObj.lastError = MountObj.MountDriverHndl.lastError
    MountObj.Port = MountObj.MountDriverHndl.Port;
end
