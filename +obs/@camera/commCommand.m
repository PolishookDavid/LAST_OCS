function [varargout]=commCommand(Obj,RemoteObj,Command)
    %

    if isempty(RemoteObj)
        % do nothing
        % Return NaNs
        [varargout{1:nargout}] = deal(NaN);
    else

        if isa(RemoteObj,'obs.remoteClass')
            % NEED TO WRITE THIS PART
            [varargout{1:nargout}] = obs.classCommand(RemoteObj,Command);
        else
            %

            [varargout{1:nargout}] = RemoteObj.(Command);

        end
    end

end
