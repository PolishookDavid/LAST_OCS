function Val=getCameraProp(Obj,Prop)
    % a general getter for camera property
    % Example: Obj.getCameraProp('ExpTime');

    % get info from remote cameras
    % check how many cameras are remotely connected
    if isempty(Obj.HandleRemoteC)
        Nrc = 0;
    else
        Nrc = Obj.classCommand(Obj.HandleRemoteC,'numel','(1:end)');
    end
    Nc  = numel(Obj.HandleCamera);

    Ind = 0;
    % get remote prop
    for Irc=1:1:Nrc
        Ind = Ind + 1;
        Tmp = Obj.classCommand(Obj.HandleRemoteC,Prop,Irc);
        if ischar(Tmp)
            Val{Ind} = Tmp;
        elseif isnumeric(Tmp)
            Val(Ind) = Tmp;
        else
            error('Unknown classCommand return option');
        end
    end

    for Ic=1:1:Nc
        Ind = Ind + 1;
        Tmp = Obj.HandleCamera(Ic).(Prop);
        if ischar(Tmp)
            Val{Ind} = Tmp;
        elseif iscellstr(Tmp)
            Val{Ind} = Tmp{1};
        elseif isnumeric(Tmp)
            Val(Ind) = Tmp;
        else
            error('Unknown classCommand return option');
        end
    end


end
