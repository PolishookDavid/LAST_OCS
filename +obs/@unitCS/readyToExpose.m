function [ready,status]=readyToExpose(Unit,itel,wait,timeout)
% check if the unit is ready to start an exposure, which means:
%
%  * Mount.Status           = idle | tracking
%  * Camera{itel}.CamStatus = idle
%  * Focuser{itel}.Status   = idle
%
% if the status of one of the devices becomes bad, abort and
%  report an error. Bad means:
%
%  * Mount.Status           = disconnected | unknown
%  * Camera{itel}.CamStatus = unknown
%  * Focuser{itel}.Status   = unknown | stuck
%
% Inputs:
%  - itel    : indices of the telescopes to monitor. All of them if empty
%  - wait    : false|true block and keep polling till all stati are ok
%                        (before timeout). Default false
%  - timeout : in seconds before giving up. Default 20

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
t0=now;

status=struct('mount','','camera',cell(size(itel)),'focuser',cell(size(itel)));

while ~ready && wait && (now-t0)*86400 < timeout
end