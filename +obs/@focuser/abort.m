function abort(Foc)
% Stops the focuser movement
    Foc.FocHn.abort;
    switch Foc.FocHn.lastError
        case "could not abort motion, communication problem?"
            Foc.lastError = "could not abort motion, communication problem?";
    end
end
