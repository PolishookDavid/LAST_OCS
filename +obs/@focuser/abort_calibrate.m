function abort_calibrate(Foc)
    Foc.FocHn.abort_calibrate;
    Foc.LastError = Foc.FocHn.lastError;
end
