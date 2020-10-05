function abort(Focuser)
% Stops the focuser movement
    Focuser.Handle.abort;
    Focuser.LastError = Focuser.Handle.LastError;
end
