function [ready,status]=readyToExpose(Unit,itel,wait,timeout)
% Check whether a set of telescopes of the unit is ready to start an exposure,
%  which means:
%
%  * Mount.Status           = idle | tracking | home | aborted
%  * Camera{itel}.CamStatus = idle
%  * CameraPower[itel]      = true
%  * Focuser{itel}.Status   = idle
%
% If the status of one of the devices becomes bad, abort and report an 
%  error. Bad means:
%
%  * Mount.Status           = disabled | unknown
%  * Camera{itel}.CamStatus = unknown
%  * CameraPower[itel]      = false
%  * Focuser{itel}.Status   = unknown | stuck
%
% Syntax : [ready,status]=readyToExpose(Unit,itel,wait,timeout)
%
% Inputs:
%  - itel    : indices of the telescopes to monitor. All of them, if empty
%  - wait    : [false|true] block and keep polling till all stati are ok
%                           (before timeout). Default, false
%  - timeout : in seconds before giving up. Default, 20
%
% Outputs:
%  - ready  : true or false
%  - status : a structure with the status of all devices checked
%
%  Note: in case of one of the faults above, the function exits as soon
%         as the first bad status is detected, without checking
%         all the other devices. The status structure will therefore
%         contain incomplete information
%
% Author: Enrico, August 2021

if ~exist('itel','var') || isempty(itel)
    itel=1:numel(Unit.Camera);
end
if ~exist('wait','var')
    wait=false;
end
if ~exist('timeout','var')
    timeout=20;
end

ready=false;
fault=false;
t0=now;

status=struct('mount','','camera',{cell(size(itel))},...
              'power',false(size(itel)),'focuser',{cell(size(itel))});

while ~ready && (now-t0)*86400 < timeout
    status.mount=Unit.Mount.classCommand('Status');
    ready = any(strcmp(status.mount,{'idle','tracking','home','aborted'}));
    fault = any(strcmp(status.mount,{'disabled','unknown',''}));
    if fault
        faultcause=sprintf('Mount %s status is: %s',...
                            Unit.Mount.classCommand('Id'),status.mount);
        break
    end
    for i=itel
        status.camera{i}=Unit.Camera{i}.classCommand('CamStatus;');
        status.power(i)=Unit.classCommand(sprintf('CameraPower(%d);',i));
        status.focuser{i}=Unit.Focuser{i}.classCommand('Status;');
        ready = ready && strcmp(status.camera{i},'idle') && status.power(i) ...
                      && strcmp(status.focuser{i},'idle');
        fault = fault || any(strcmp(status.camera{i},{'unknown',''}));        
        if fault
            faultcause=sprintf('Camera %s status is: %s',...
                                Unit.Camera{i}.classCommand('Id'),status.camera{i});
            break
        end
        fault = fault || ~status.power(i);
        if fault
            faultcause=sprintf('Camera %s power is OFF',...
                                Unit.Camera{i}.classCommand('Id'));
            break
        end
        fault = fault || any(strcmp(status.focuser{i},{'stuck','unknown',''}));
        if fault
            faultcause=sprintf('Focuser %s status is: %s',...
                                Unit.Focuser{i}.classCommand('Id'),status.focuser{i});
            break
        end
    end
    if ~wait
        break
    end
    if ~ready && wait
        Unit.report('unit not yet ready to shoot images, waiting...\n')
    end
    % status query commands take already some time, hence don't add pauses
end

if fault
    Unit.reportError(faultcause);
elseif wait && ~ready
    Unit.report(sprintf('unit still not ready to shoot after %.1f seconds\n',...
                        (now-t0)*86400));
end
