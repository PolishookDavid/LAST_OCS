function abort_calibrate(F)
    F.FocHn.abort_calibrate;
    switch F.FocHn.lastError
        case "not able to abort calibration!"
            F.lastError = "not able to abort calibration!";
    end
end
