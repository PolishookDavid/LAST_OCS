function abortablePause(Unit,seconds_to_wait)
% waits the prescribed number of seconds, but exits earlier if
%  Unit.AbortActivity becomes true. This could be set by a callback, and
%  works because Unit is a handle class, hence accessible in all workspaces
% Unit.AbortActivity is not reset to false before exiting.
    t0=now;
    while (now-t0)*86400<seconds_to_wait
        if Unit.AbortActivity
            break
        else
            pause(0.1)
        end
    end