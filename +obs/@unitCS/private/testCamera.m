function ok=testCamera(U,camnum,full)
% check the functionality of a camera. Ancillary of checkCamera().
% This function may be called repeatedly if remediate
    arguments
        U obs.unitCS
        camnum double;
        full logical =false; % test full operation, e.g. move focusers, take images
    end
    
    status=U.Camera{camnum}.classCommand('CamStatus');
    if isempty(status)
        U.report('retrieved no camera %d status\n',camnum)
        ok=false;
    end
    
    gain=U.Camera{camnum}.classCommand('Gain');

    if ~isempty(status)
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
    end
    % specific tests for QHY
    model=U.Camera{camnum}.classCommand('CameraModel');
    if ~isempty(model) && contains(model,'QHY')
        allcameras=U.Camera{camnum}.classCommand('allQHYCameraNames');
        physicalid=U.Camera{camnum}.classCommand('PhysicalId');
        if ~contains(allcameras,physicalid)
             U.report('camera %s is not even known registered on the computer\n',...
                      physicalid)
             U.report('check if the camera is physically connected and powered,\n')
             U.report('or otherwise check that the obs.camera configuration file is correct\n')
             ok=false;
        end 
        if ok && gain>10000
        % this is an indication of something fishy only for QHY
            U.report('anomalous gain value of %f means something fishy\n',gain)
            ok=false;
        end
    end
    if ok && full
        U.report('attempting to take one single image\n',camnum)
        U.takeExposure(camnum,1);
        pause(10) % should be sufficient for switching mode, readout
        ok=U.Camera{camnum}.classCommand('ProgressiveFrame')==1;
        if isempty(U.Camera{camnum}.classCommand('LastImageName')) && ...
           U.Camera{camnum}.classCommand('SaveOnDisk')
            U.report('image was not saved on disk. Check if disks are mounted\n')
            U.report('or if paths in obs.camera config file are correct\n')
        end
        if ok
            U.report('attempting to take three contiguous images\n',camnum)
            U.takeExposure(camnum,5,3);
            pause(30) % should be sufficient for switching mode, readout
            ok=U.Camera{camnum}.classCommand('ProgressiveFrame')==3;
            if ~ok
                U.report('continuous exposure taking too long\n',camnum)
            end
        else
            U.report('no image taken, apparently\n',camnum)
        end
    end
end
