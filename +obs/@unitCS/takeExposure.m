function Flag=takeExposure(Unit,Cameras,ExpTime,Nimages,varargin)
    % Take a single or multiple number of exposures
    % Package: +obs.@unitCS
    % Input  : - a vector of camera indices
    %          - Exposure time [s]. If provided this will override
    %            the CameraObj.ExpTime, and the CameraObj.ExpTime
    %            will be set to this value.
    %          - Number of images to obtain. Default is 1.
    %          * ...,key,val,...
    %            'WaitFinish' - default is true.
    %            'SaveMode' - default is 2.
    %            'ImType' - default is [].
    %            'Object' - default is [].
    % Output : - Sucess flag.


    InPar = inputParser;
%            addOptional(InPar,'WaitFinish',true);
    addOptional(InPar,'WaitFinish',false);
    addOptional(InPar,'ImType',[]);
    addOptional(InPar,'Object',[]);
    addOptional(InPar,'SaveMode',2);
    parse(InPar,varargin{:});
    InPar = InPar.Results;

    Ncam = numel(Cameras);

    if InPar.SaveMode==1 && Ncam>1
        error('SaveMode=1 is allowed only for a single camera');
    end


    if ~isempty(InPar.ImType)
        % update ImType
        Unit.CameraObj{Cameras}.ImType = InPar.ImType;
    end
    if ~isempty(InPar.Object)
        % update ImType
        Unit.CameraObj{Cameras}.Object = InPar.Object;
    end

    MinExpTimeForSave = 5;  % [s] Minimum ExpTime below SaveDuringNextExp is disabled


    if nargin<3
        Nimages = 1;
        if nargin<2
            ExpTime = Unit.CameraObj{Cameras}.ExpTime;
        end
    end
    %ExpTime = CameraObj.ExpTime;

    if numel(unique(ExpTime))>1
        error('When multiple cameras all ExpTime need to be the same');
    end
    ExpTime = ExpTime(1);

    if Nimages>1 && ExpTime<MinExpTimeForSave && InPar.SaveMode==2
        error('If SaveMode=2 and Nimages>1 then ExpTime must be above %f s',MinExpTimeForSave);
    end


    Flag = false;
    if all([Unit.CameraObj{Cameras}.IsConnected])
        %Status = CameraObj.Status;
        %SaveDuringNextExp = CameraObj.SaveDuringNextExp;

        % take Nimages Exposures
        for Iimage=1:1:Nimages

            %if isIdle(CameraObj(1))
            if all(isIdle(CameraObj))
                % all cameras are idle

                for Icam=1:1:Ncam
%                             if Icam>1
%                                 if isIdle(CameraObj(Icam))
%                                     % continue
%                                 else
%                                     CameraObj(Icam).waitFinish;
%                                 end
%                             end

                    % Execute exposure command
                    CameraObj(Icam).Handle.takeExposure(ExpTime);
                    if CameraObj(Icam).Verbose
                        fprintf('Start Exposure %d of %d: ExpTime=%.3f s\n',Iimage,Nimages,ExpTime);
                    end
                    CameraObj(Icam).LogFile.write(sprintf('Start Exposure %d of %d: ExpTime=%.3f s',Iimage,Nimages,ExpTime));
                end  % end of Icam loop

                switch InPar.SaveMode
                    case 1
                        % start a callback timer that will save
                        % the image immidetly after it is taken

                        % start timer
                        CameraObj(Icam).SaveWhenIdle = false;
                        CameraObj(Icam).ReadoutTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate',...
                                                       'Name', 'camera-timer',...
                                                       'Period', 0.2, 'StartDelay', max(0,ExpTime-1),...
                                                       'TimerFcn', @CameraObj.callbackSaveAndDisplay,...
                                                       'ErrorFcn', 'beep');
                        start(CameraObj(Icam).ReadoutTimer);
                    case 2
                        % save and display while the next image
                        % is taken
                        if Iimage>1
                            for Icam=1:1:Ncam
                                if CameraObj(Icam).Verbose
                                    fprintf('Save Image %d of camera %d\n',Iimage-1,Icam);
                                end
                                CameraObj(Icam).SaveWhenIdle = true;
                                %size(CameraObj(Icam).LastImage)
                                callbackSaveAndDisplay(CameraObj(Icam));

                            end
                        end
                end

                if InPar.WaitFinish
                    % blocking
                    CameraObj.waitFinish;
                    %size(CameraObj(Icam).LastImage)
                end

            else
                % not idle
                if all([CameraObj.Verbose])
                    fprintf('Can not take Exposure because at least one camera is not idle\n');
                end
                CameraObj.LogFile.write(sprintf('Can not take Exposure because at least one camera is not idle'));
            end

        end  % end for loop

        switch InPar.SaveMode
            case 2
                for Icam=1:1:Ncam
                    if CameraObj(Icam).Verbose
                        fprintf('Save Image %d of camera %d\n',Nimages,Icam);
                    end
                    CameraObj(Icam).SaveWhenIdle = true;
                    callbackSaveAndDisplay(CameraObj(Icam));

                end
            otherwise
                % do nothing
        end

        Flag = true;

    end

end
