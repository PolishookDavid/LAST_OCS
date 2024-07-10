function [ok,remedy]=checkSwitches(U,remediate,itel)
    % check power switches (note: some of these tests take in consideration
    %  only tinycontrol IP power sockets, e.g. assuming that there are 6
    %  outputs
    % Also, stricly speaking this is not just a test on switches, but also
    %  on which switches are needed for the Unit telescopes in question
    arguments
        U obs.unitCS;
        remediate logical = false; % attempt remediation actions
        itel = numel(U.Camera);
    end

    ok=true;
    remedy=false;

    % potential errors:
    %   no switches defined
    if isempty(U.PowerSwitch)
        U.report('No power switches defined for this unit\n')
        ok=false;
    end
    
    relevantswitches=false(1,numel(U.PowerSwitch));
    relevantswitches(U.MountPowerUnit)=true;    
    relevantswitches(U.CameraPowerUnit(itel))=true;    
    
    %   no communication with the switches
    if ok
        for i=1:find(relevantswitches)
            if isempty(U.PowerSwitch{i}.classCommand('Outputs'))
                U.report('cannot retrieve the output status of switch %d\n',i)
                ok=false;
                if ~ok && remediate
                    remedy=true;
                    U.report('attempting reconnection of switch %d\n',i)
                    U.PowerSwitch{i}.classCommand('connect')
                    ok=isempty(U.PowerSwitch{i}.classCommand('LastError'));
                    if ~ok
                        U.report('reconnection of switch %d failed\n',i)
                    end
                end
            end
        end
    end

    % mount and camera power not defined on available units or outputs
    if isempty(U.MountPowerUnit) || isempty(U.CameraPowerUnit(itel)) || ...
       U.MountPowerUnit<1 || U.MountPowerUnit>numel(U.PowerSwitch) || ...
       any(U.CameraPowerUnit(itel)<1 | U.CameraPowerUnit(itel)>numel(U.PowerSwitch)) ||...
       U.MountPowerOutput<1 || U.MountPowerOutput>6 || ...
       any(U.CameraPowerOutput(itel)<1 | U.CameraPowerOutput(itel)>6)
       U.report('inconsistent definition of power switches outputs\n')
       U.report('check obs.unitCS.%s.create configuration file\n',U.Id)
        ok=false;
    end
