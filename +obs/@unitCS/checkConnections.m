function [ok,report]=checkConnections(U,remediate)
% perform several sanity tests and checks on the objects of the unit,
% check the connection status with the hardware,
% and report and optionally attempt to solve problems
    arguments
        U obs.unitCS
        remediate logical = false;
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
                    U.CameraPower(i)=true;
                end
            end
        catch
            % abort
        end
        
        for i=1:numel(U.Camera)
            try
                if ~U.CameraPower(i)
                    if remediate
                        U.CameraPower(i)=true;
                    end
                end
            catch
                % not enough elements in CameraPower or communication error
                % abort
            end
        end
    
    % check communication with mount
    % remediation: power cycle
    
    % check for mount faults
    % remediation: clearFaults
    
    % possibility that there are local cameras and focusers: check them
    % first
    
    % check communication with slaves
    for i=1:numel(U.Slave)
        % within them, check all owned cameras and focusers
    end
