function abort_calibrate(F)
    F.FocuserDriverHndl.abort_calibrate;
    switch F.FocuserDriverHndl.lastError
        case "not able to abort calibration!"
            F.lastError = "not able to abort calibration!";
    end
end
