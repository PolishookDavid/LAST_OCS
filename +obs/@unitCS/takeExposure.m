function takeExposure(Unit,Cameras,ExpTime,Nimages, InPar)
    % Take one or many exposures from one or many local or remote cameras,
    %  using nonblocking calls to start exposing.
    % If requested, wait till the mount has finished slewing, the focusers
    %  moving and the camera shooting
    %
    % Package: +obs.@unitCS
    % Input  : - a vector of camera indices [all cameras if omitted]
    %          - Exposure time [s]. If provided this will override
    %            the Camera.ExpTime, and the Camera.ExpTime
    %            will be set to this value.
    %          - Number of images to obtain. Default is 1.
    %          * ...,key,val,... :
    %            'WaitFinish' - default is false (to reduce delays)
    %            'ImType'     - (passed along to write image file), default is 'sci'
    %                       If empty, will not be changed.
    %            'Object'     - (passed along to write image file), default is NaN.
    %                       If NaN will insert field name based on
    %                       coordinate name.
    %                       If empty, will insert empty object.
    %            'MinExpTimeForSave' - default is 5 [sec]. .SaveOnDisk
    %                                  will be temporarily turned off if
    %                                  ExpTime is smaller than that.
    %                                  (BUG - doesn't happen)
    %            'LiveSingleImage' - default is false. Use Live acquisition
    %                        even when acquiring just one image. Overhead
    %                        times are larger (the first image is available
    %                        only after two exposure times + starting
    %                        overheads), but offset, which may be different
    %                        between modes (!) will be consistent with that
    %                        of live acquisitions
    % TAKE CARE, Unit.Camera{i}.classCommand('waitFinish') may timeout
    %  because of no reply, if the messenger timeout is shorter than
    %  ExpTime. Consider using the method readyToExpose(...,true,timeout)
    %  for finer control.
    
    % argument parsing
    arguments
        Unit
        Cameras   = [];
        ExpTime   = [];
        Nimages   = 1;
        InPar.WaitFinish logical   = false;
        InPar.ImType               = 'sci';
        InPar.Object               = NaN;
        InPar.MinExpTimeForSave    = 0.75;
        InPar.LiveSingleImage      = false;
    end
        
    Unit.reportDebug('entering takeExposure\n')
    
    if isempty(Cameras)
        Cameras = (1:numel(Unit.Camera));
    end
    Ncam  = numel(Cameras);
    
    if isempty(ExpTime)
        ExpTime=zeros(size(Cameras));
        for i=1:numel(Cameras)
            ExpTime(i) = Unit.Camera{Cameras(i)}.classCommand('ExpTime');
        end
    else
        if numel(ExpTime)==1
            ExpTime=repmat(ExpTime,size(Cameras));
        end 
        for i=1:numel(Cameras)
            Unit.Camera{Cameras(i)}.classCommand('ExpTime=%f;',ExpTime(i));
        end
    end

    if ~isempty(InPar.ImType)
        % update ImType
        for Icam=1:1:Ncam
            Unit.Camera{Cameras(Icam)}.classCommand(sprintf('ImType=''%s'';',InPar.ImType));
        end
    end
    % update Object
    if isnan(InPar.Object)
        % If Object is NaN then will set the object name to coordinates
        Coo = Unit.Mount.classCommand('j2000;');
        InPar.Object = sprintf('%03d%+03d',round(mod(Coo(1),360)), round(Coo(2)));
    end

    for Icam=1:1:Ncam
        Unit.Camera{Cameras(Icam)}.classCommand(sprintf('Object=''%s'';',InPar.Object));
    end
    
    if Nimages>1 && min(ExpTime) < InPar.MinExpTimeForSave
        Unit.reportError([sprintf('If Nimages>1 then ExpTime must be above %g s',...
                          InPar.MinExpTimeForSave),...
                        '; camera.SaveOnDisk will be turned off for all cameras involved']);
        % keep the previous SaveOnDisk status
        saving=false(size(Cameras));
        for i=Cameras
            saving(i)=Unit.Camera{i}.classCommand('SaveOnDisk;');
            Unit.Camera{i}.classCommand('SaveOnDisk=false;');
            % however, this seems to have had no effect inside
            % unitCS.treatNewImage. Why? some issue of snapshotting the
            % object at the moment of creation of the listener, or
            % something intricate else?
        end
    end

    % end argument parsing
    
    % wait before starting, if asked to
    if InPar.WaitFinish
        Unit.Mount.classCommand('waitFinish;');
        % wait sequentially for each camera, because camera.waitFinish
        %  has been implemented scalarly. No big deal however, because
        %  at the end we'll proceed only when the last of the busy cameras
        %  is free, no matter the order of checking
        % NOTE: THIS IS PROBLEMATIC WITH REMOTE OBJECTS
        for i=Cameras
            Unit.Focuser{i}.classCommand('waitFinish;');
            Unit.Camera{i}.classCommand('waitFinish;');
        end
    end

    % check that all the requested cameras are able to take exposures (a
    % bit superfluous perhaps). Do it in a preliminary loop, because we
    % want to send the exposure command to all cameras as simulatneously as
    % possible, without waiting for a query turnover
    CamStatus=cell(1,max(Cameras));
    for i=Cameras
        CamStatus{i}=Unit.Camera{i}.classCommand('CamStatus;');
    end
    % start acquisition on each of the local cameras, using nonblocking
    %  methods, and of the remote ones, using blind sends for maximum speed.
    %  This difference prevents the use of .classCommand() for both
    Unit.reportDebug('commanding cameras to expose\n')
    
    for i=Cameras
        if strcmp(CamStatus{i},'idle')
            if isa(Unit.Camera{i},'obs.remoteClass')
                remotename=Unit.Camera{i}.RemoteName;
                if Nimages>1 || InPar.LiveSingleImage
                    Unit.Camera{i}.Messenger.send(sprintf('%s.takeLive(%d)',remotename,Nimages));
                else
                    Unit.Camera{i}.Messenger.send(sprintf('%s.takeExposure',remotename));
                end
            else
                if Nimages>1 || InPar.LiveSingleImage
                    Unit.Camera{i}.takeLive(Nimages);
                else
                    Unit.Camera{i}.takeExposure;
                end
            end
            % otherwise it would be just:
            %         if Nimages>1
            %             Unit.Camera{i}.classCommand('takeLive(%d)',Nimages);
            %         else
            %             Unit.Camera{i}.classCommand('takeExposure');
            %         end
        else
            Unit.reportError('Camera %d status is "%s", cannot take exposures!',...
                             i,CamStatus{i})
        end
    end
    
    % query the mount and the temperature sensor at this point, construct
    %  .UnitHeader and dispatch it to the slaves. Let's hope for the time
    %  being that this is faster than the time it takes to arm the camera
    %  and retrieve an exposure, else the FITS file will be written with an
    %  outdated header
    Unit.constructUnitHeader;
    
    UnitName=inputname(1);
    headerline=obs.util.tools.headerInputForm(Unit.UnitHeader);
    % here we assume implicitly that we have one camera per Slave, and that
    %  all Cameras are remote, because we want to use the Responder, for
    %  setting Unit.UnitHeader with the earliest possible callback. If we
    %  were using the Camera{i}.Messenger, we would depend on the completion
    %  of the exposure command
    for i=Cameras
       Unit.Slave(i).Responder.send(sprintf('%s.UnitHeader=%s;',UnitName,headerline)); 
    end
    
    % restore the previous SaveOnDisk status if needed
     if Nimages>1 && min(ExpTime) < InPar.MinExpTimeForSave
        for i=Cameras
            Unit.Camera{i}.classCommand('SaveOnDisk=%d;',saving(i));
        end
    end
   

end
