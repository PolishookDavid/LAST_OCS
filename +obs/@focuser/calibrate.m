function calibrate(F)
% Run the calibration routine to find the movement limits.
% Beware, the process takes a few minutes, like 3-4.
% With less than perfect USB connection, this causes an almost certain disconnection
%  within a few seconds. A pita. The stale serial resource needs to be
%  deleted, and a new connection has to be estabilished on probably a new
% assigned USB resource.
% Or to say it better: doesnt't matter, take for granted that the focuser
% will disconnect itself, just reconnect it after a few minutes.
    F.FocHn.calibrate;
    if(strfind(F.FocHn.lastError, 'Calibration failed')),
       F.lastError = F.FocHn.lastError;
    elseif (strfind(F.FocHn.lastError, 'Calibration timed out!')),
       F.lastError = F.FocHn.lastError;
    end
end
