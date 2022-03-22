function ok=checkFocuser(U,focnum,full,remediate)
% check the functionality of a single focuser, report problems and
%  suggest remedies. This method is specifically designed to check
%  one of the .Focuser{} properties of unitCS, which can be either an
%  instrument or a remote class: 
%  it is therefore an obs.unitCS method, not a obs.focuser method.
%  It is mostly intended to be used in the
%  session where the master unitCS object is defined. If the Focuser{}
%  is remote, the sanity of containing slave and messengers is tacitly
%  assumed (it is checked elsewhere)
% Arguments:
% if full=true, try to nudge the focuser for a more comprehensive
%   (longer) test
% if remediate=true, try to apply some remedies
    arguments
        U obs.unitCS
        focnum double;
        full logical =false; % test full operation, e.g. move focusers
        remediate logical = false; % attempt remediation actions
    end

    ok=true;

    % check status
    status=U.Focuser{focnum}.classCommand('Status');
    if ~isempty(U.Focuser{focnum}.classCommand('LastError'))
        U.report('cannot communicate with focuser %d\n',focnum)
        ok=false;
        if remediate
    % remediation: attempt reconnect
            U.Focuser{focnum}.classCommand('connect')
            ok=isempty(U.Focuser{focnum}.classCommand('LastError'));
        end
    end

    if isempty(status) % happens e.g. for uninitialized remote class
        U.report('Focuser %d status not retrieved\n',focnum)
        ok=false;
    end
    
    if ok
        switch status
            case 'idle'
                ok=true;
            case 'stuck'
                ok=false;
                U.report('focuser %d is stuck!\n',focnum)
            otherwise
                ok=false;
                U.report('focuser %d is %s, try again later\n',focnum,status)
        end
    end

    % check sane limits
    if ok
         l=U.Focuser{focnum}.classCommand('Limits');
         if isempty(l) || l(1)==l(2)
             ok=false;
             U.report(['inconsistent focuser limits: perhaps focuser %d',...
                       ' needs calibration?\n'],focnum)
         end
    end

    if ok && full
        % nudge the focuser
        nudge=100;
        p=U.Focuser{focnum}.classCommand('Pos');
        if (p+nudge)>l(2)
            nudge=-nudge;
        end
        U.report('trying to move focuser %d of %d steps\n',focnum,nudge)
        U.Focuser{focnum}.classCommand('RelPos=%d;',nudge);
        pause(3)
        U.report('trying to move focuser %d of %d steps\n',focnum,-nudge)
        U.Focuser{focnum}.classCommand('RelPos=%d;',-nudge);
        pause(3)
        status=U.Focuser{focnum}.classCommand('Status');
        if ~strcmp(status,'idle') || ...
           ~isempty(U.Focuser{focnum}.classCommand('LastError'))
            ok=false;
            U.report('focuser %d failed nudging test\n',focnum)
        else
            ok=true;
        end
    end