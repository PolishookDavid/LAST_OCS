function abort(Foc)
% Stops the focuser movement
    Foc.FocHn.abort;
    Foc.LastError = Foc.FocHn.lastError;
end
