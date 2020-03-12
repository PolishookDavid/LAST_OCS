function abort(F)
% stops the focuser movement
    F.FocuserDriverHndl.abort;
    switch F.FocuserDriverHndl.lastError
        case "could not abort motion, communication problem?"
            F.lastError = "could not abort motion, communication problem?";
    end
end
