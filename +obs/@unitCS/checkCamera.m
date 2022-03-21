function ok=checkCamera(U,camnum,full,remediate)
% check the functionality of a single camera, report problems and
%  suggest remedies. This method is specifically designed to check
%  one of the .Camera{} properties of unitCS, which can be either an
%  instrument or a remote class; moreover it also checks .CameraPower: 
%  it is therefore an obs.unitCS method, not a obs.camera method.
%  It is mostly intended to be used in the
%  session where the master unitCS object is defined. If the Camera{}
%  is remote, the sanity of containing slave and messengers is tacitly
%  assumed (it is checked elsewhere)
% Arguments:
% if full=true, try to acquire some images for a more comprehensive
%   (longer) test
% if remediate=true, try to apply some remedies like attempting to
%   reconnect or power cycle the camera
    arguments
        U obs.unitCS
        camnum double;
        full logical =false; % test full operation, e.g. move focusers, take images
        remediate logical = false; % attempt remediation actions
    end

% check if powered on
    try
        ok=U.CameraPower(camnum);
        if ~ok
            U.report('camera %d power is off\n',camnum)
            if remediate
                U.report('turning on and trying to connect\n',camnum)
                U.CameraPower(camnum)=true;
                U.Camera{camnum}.classCommand('connect');
                ok=true; % not really guaranteed ok, just a flag to go on
            end
        end
    catch
        ok=false;
        % not enough elements in CameraPower or communication error
        U.report('cannot turn on power for camera %d\n',camnum)
    end
        
% check status:
    if ok
        try
            U.report('checking status of camera %d\n',camnum)
            ok=testCamera(U,camnum,full);
            if ~ok && remediate
                U.report('trying plain reconnect of camera %d\n',camnum)
                U.Camera{camnum}.classCommand('connect');
                ok=testCamera(U,camnum,full);
                if ~ok
                    U.report('trying power cycle and reconnect of camera %d\n',camnum)
                    U.CameraPower(camnum)=false;
                    pause(1)
                    U.CameraPower(camnum)=true;
                    U.Camera{camnum}.classCommand('connect');
                    ok=testCamera(U,camnum,full);
                end
            end           
        catch
            U.report('communication with the camera object failed or some other bad thing\n')
        end
    end