function [Ready,Status]=readyToExpose1(Unit, Args)
% readyToExpose1
% Input  : - An obs.unitCS object
%          * ...,key,val,...
%            'Itel' - List of telescopes to check. If empty use (1:1:4).
%                   Default is [].
%            'Wait' - A logical indicating if to wait till the system is
%                   ready. Default is false.
%            'Timeout' - Time out for waiting. Default is 20 [s].
%            'ClearMountFaults' - A logical indicating if to clear mount
%                   faults. Default is true.
%            'Test - A vector of 3 logicals indicating if to test [mount,
%                   focusers, cameras].
%                   Default is true(1,3).
% Output : - A logical indicating if the requested components are ready.
%          - A status structure.
% Author : Eran Ofek (Apr 2022)
% Example:


arguments
    Unit
    Args.Itel                        = [];
    Args.Wait logical                = false; 
    Args.Timeout                     = 20;
    Args.ClearMountFaults logical    = true;
    Args.Test                        = [true, true, true];  % test: mount, focuser, camera
end
SEC_IN_DAY = 86400;

if isempty(Args.Itel)
    Args.Itel = (1:1:4);
end
Ncam = numel(Args.Itel);


Ready = false;
Fault = false;
T0    = now;

Status=struct('mount','','camera',{cell(size(itel))},...
              'power',false(size(itel)),'focuser',{cell(size(itel))});

CameraId = nan(1,Ncam);

while Args.Wait && ~Ready && ((now-T0).*SEC_IN_DAY)<Args.Timeout

    for It=1:Ncam
        TmpID = Unit.Camera{Args.Itel(It)}.classCommand('Id');
        % e.g., '82-1-3'
        SpID = split(TmpID, '-');
        if numel(SpID)==3
            CameraId(It) = num2str(SpID{3});
        else
            % Assume no communication with slave
            CameraId(It) = NaN;
            Fault = true;
        end
    end

    CommSlavesOK = ~any(isnan(CameraId));

    if CommSlavesOK
        % Slavs are responsive - check mount

        if Args.Test(1)
            MountOK = false;
            Counter = 0;
            while ~MountOK && Counter<2
                Counter = Counter + 1;
                Status.mount = Unit.Mount.classCommand('Status');
                switch lower(Status.mount)
                    case {'idle','tracking','home','aborted'}
                        MountOK = true;
                    otherwise
                        MountOK = false;

                        % try to clear faults
                        if Args.ClearMountFaults
                            Unit.Mount.clearFaults;
                        end
                end
            end
        else
            MountOK = true;
        end

        if MountOK
            % Mount is ok - check the focusers
            if Args.Test(2)
                FocuserReady = false(1, Ncam);
                for Icam=1:1:Ncam
                    Status.focuser{Icam} = Unit.Focuser{Args.Itel(Icam)}.classCommand('Status;');
                    FocuserReady(Icam)   = strcmp(Status.focuser{Icam}, 'idle');
                end
            else
                FocuserReady = true(1, Ncam);
            end

            if all(FocuserReady)
                % focusrer are ready - check camera
                CameraReady = false(1, Ncam);
                if Args.Test(3)
                    for Icam=1:1:Ncam
                        Status.camera{Icam} = Unit.Camera{Args.Itel(Icam)}.classCommand('CamStatus;');
                        CameraReady(Icam)   = strcmp(Status.camera{Icam}, 'idle');
                    end
                else
                    CameraReady = true(1, Ncam);
                end
            end
        end

        Ready = CommSlavesOK && MountOK && all(FocuserReady) && all(CameraReady);
    end
end
    
    