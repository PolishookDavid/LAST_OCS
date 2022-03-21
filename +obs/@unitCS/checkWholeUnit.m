function [ok,report]=checkWholeUnit(U,full,remediate)
% perform several sanity tests and checks on the objects of the unit,
% check the connection status with the hardware,
% and report and optionally attempt to solve problems
    arguments
        U obs.unitCS
        full logical =false; % test full operation, e.g. move focusers, take images
        remediate logical = false; % attempt remediation actions
    end
    
    % check power switches
        % potential errors:
        %   no switches defined
        %   no communication with switches
        %   mount and camera power not defined on available units
        % abort if any of the above happens
        
        % check power
        try
            if ~U.MountPower               
                if remediate
                    U.MountPower(i)=true;
                end
            end
            ok=true;
        catch
            % abort
            ok=false;
        end
        
    % check communication with mount
    % remediation: power cycle
    
    % check for mount faults
    % remediation: clearFaults
    
    % check communication with slaves
    for i=1:numel(U.Slave)
        status=U.Slave{i}.Status;
        U.report('Slave %d status: "%s"\n',i,status)
        ok=strcmp(status,'alive');
        if ~ok && remediate
            % attempt disconnection and reconnection            
            U.Slave{i}.disconnect;
            pause(15)
            U.connectSlave(i)
            ok=strcmp(U.Slave{i}.Status,'alive');
        end
    end
    
    for i=1:numel(U.Camera)
        U.checkCamera(i,remediate,full)
    end
    
    for i=1:numel(U.Focuser)
        % check status
        % check sane limits
        % remediation: reconnect
    end
