function abort_calibrate(Focuser)
    Focuser.Handle.abort_calibrate;
    Focuser.LastError = Focuser.Handle.lastError;
end
