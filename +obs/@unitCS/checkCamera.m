function ok=checkCamera(U,camnum,full,remediate)
% check the functionality of a single camera, report problems and
%  suggest remedies
% if full=true, try to acquire some images for a more comprehensive
%   (longer) test
% if remediate=true, try to apply some remedies like attempting to
%   reconnect or power cycle the camera

% check if powered on
    try
        if ~U.CameraPower(camnum)
            U.report('camera %d power is off\n',camnum)
            if remediate
                U.CameraPower(camnum)=true;
            end
        end
        ok=true;
    catch
        ok=false;
        % not enough elements in CameraPower or communication error
        U.report('cannot turn on power for camera %d\n',camnum)
    end
        
% check status
    if ok
        try
            status=U.Camera{camnum}.classCommand('CamStatus');
            gain=U.Camera{camnum}.classCommand('Gain');
            switch status
                case 'idle'
                    ok=true;
                    U.report('camera %d is idle, good\n',camnum)
                case 'unknown'
                    ok=false;
                    U.report('camera %d status is unknown, bad sign\n',camnum)
                otherwise
                    ok=false;
                    U.report('camera %d is "%s", try perhaps later\n',camnum,status)
            end
            if gain>10000
                % this is an indication of something fishy only for QHY
                if contains(U.Camera{camnum}.classCommand('CameraModel'),'QHY')
                end
            end
            % check U.Slave.Messenger.LastError for communication problems
        catch
        end
    end