function observeList(Unit, Args)
    % A function that use a single mount to observe a list of targets from the scheduler.
    % Input  : - Unit object.
    %          * ...,key,val,...
    %            'GeoPos' - Geodetic position. If empty, then read from
    %                   config file. Default is [].
    %            'SumNaxAlt' - Sun max. alt. for observations [deg].
    %                   Default is -11.5.
    %            'MinNumCamToUse' - Minimum number of cameras to use. If
    %                   the number of cameras available is smaller than this
    %                   number then do not observe.
    %                   Default is 1.
    %            'SelectMethod' - Target selection method.
    %                   See telescope.Scheduler for details.
    %                   Default is 'minam'.
    %            'CameraTempFunction' - A function handle that input is the
    %                   ambient temperature, that returns the recomended
    %                   detector temperature.
    %                   Default is @(AmbientTemp) max(AmbientTemp - 25, -10);
    %
    %            'CheckAbortTime' - 
    %            'SimulationJD' - 
    %
    %

    arguments
        Unit
        Args.GeoPos          = Unit.Mount.MountPos([2 1 3]); %[35.0407331, 30.0529838    415]; % [LONG, LAT, H]
        Args.SunMaxAlt       = -11.5; % [deg]
        Args.MinNumCamToUse  = 1;

        Args.SelectMethod    = 'minam'; % ignored, responsibility of the scheduler

        Args.CameraTempFunction % left empty, because the default can't be built in the arguments block 
        Args.CheckAbortTime     = 10;  % [s] when taking exposure, will check for abort every THIS number of seconds
        
        Args.SimulationJD   = [];   % if given, then work in simulation mode
        
        Args.Mailbox= Redis('last0', 6379, 'password', 'foobared');
    end

    % The following code should be embeded in the super-script that runs
    % the observatory - NOT HERE
    % I kept it here for reference.
    % check weather and safety
    %Args.IsSafeCmd      = 'wget -o /dev/null -O - --no-proxy http://10.23.1.25:8001/last/is_safe';
    %[OutF,IsSafeOutput] = system(Args.IsSafeCmd);
    %if OutF~=0
    %    IsWatherSafe = false;
    %else
    %    SafeDecoded = jsondecode(IsSafeOutput);
    %    IsWeatherSafe = SafeDecoded.safe;
    %end


    if isempty(Args.GeoPos)
        Args.GeoPos = Unit.Mount.MountPos([2 1 3]);   % [deg, deg, m]
    end

    if isempty(Args.CameraTempFunction)
        Args.CameraTempFunction = @(AmbientTemp) max(AmbientTemp - 25, -10);
    end


    % Check hardware status
    %   Check mount connected, no faults
    % ...
    %   If needed fix problems
    % ...
    %   DO NOT set mount to home position
    %   Check cameras and focusers
    [~,~,ListOfCams] = Unit.checkWholeUnit(0,1);  % vector operational camera+focuser

    if numel(find(ListOfCams))<Args.MinNumCamToUse
        Unit.reportError('only %d cameras are available',numel(find(ListOfCams)));
        return;
    end

    % set cameras temperature
    %   Read mount temperature
    MountTemp = nanmean(Unit.Temperature);  % mount temperature [C]
    % Calculate recomended set temperature for camera
    CameraSetTemp = Args.CameraTempFunction(MountTemp);
    % set camera temperature
    for i=find(ListOfCams)
        Unit.Camera{i}.classCommand(sprintf('Temperature=%f',CameraSetTemp))
    end

    % Check that cameras Idle (superfluous, has been just done)
    % Check focusers


    if ~isempty(Args.SimulationJD)
        JD = Args.SimulationJD;
    end

    while ~Unit.AbortActivity % add also SunAlt > -11.5 & DSunAlt >0 for morning

        % Get current time
        if isempty(Args.SimulationJD)
            % JD/UTC from computer
            JD = celestial.time.julday;
        end
 
        Sun=celestial.SolarSys.get_sun(JD);
        SunAlt=Sun.Alt;
        DSunAlt=Sun.dAltdt;
            
        if Unit.AbortActivity
            break
        end

        if SunAlt<Args.SunMaxAlt
            % can observe
                        
            %post in the mailbox a request for a target and wait for a
            % reply
            requestHash=sprintf('TargetRequest:%d',Unit.MountNumber);
            success=Args.Mailbox.hset(requestHash,'Status','requesting','JD',JD);
            if ~success % or is this str2num(success)?
                Unit.reportError('cannot post target request to scheduler')
            end
            t0=now;
            timeout=10;
            while (now-t0)*86400< timeout && ...
                  ~strcmpi(Mailbox.hget(requestHash,'Status'),'provided')
              % get target
              TargetStruct=jsondecode(Mailbox.hget(requestHash,'Target'));
              Unit.AbortablePause(0.1)
            end
            if (now-t0)*86400 >= timeout
                Unit.reportError('Scheduler not providing a target')
            end
            

            if ~isempty(TargetStruct)
                % Target acquired
                Mailbox.hset(requestHash,'Status','acquired','JD',JD);

                FieldName = TargetStruct.FieldName;
                ExpTime = TargetStruct.ExpTime;   % Requested ExpTime [s]
                Nexp    = TargetStruct.Nexp;      % Requested number of images

                
                Unit.report(sprintf('Target acquired: "%s", %d exposures x %f sec',...
                    FieldName,Nexp,ExpTime));
                % go to target
                Unit.Mount.goToTarget(TargetStruct.RA,TargetStruct.Dec);

                % Checks (either specifically, or using LastErr)
                %   check for mount faults
                %   check tracking
                %   check pointing
                % If checks failed - try to recover by calling mountRecover
                % function
                if ~isempty(Unit.Mount.LastError)
                end

                % if recovery fails, or something else is unreasonable
                % (e.g. alt>MinAlt, Nexp or Texp out of limits)
                %if ....
                %Mailbox.hset(requestHash,'Status','acquired');
                %else ...

                % takeExposure
                Unit.takeExposure(find(ListOfCams),ExpTime,Nexp,'LiveSingleImage',true)

                % report in monitor
                Unit.GeneralStatus = sprintf('Observing %s',FieldID);
                % writeLog
                ReportText = sprintf('');
                Unit.report(ReportText);


                % wait for takeExposure to end and check if need to abort
                TotalWaitTime = ExpTime.*(Nexp+1);

                % wait for TotalWaitTime, but every Args.CheckAbortTime
                % seconds check for abort.
                Unit.abortablePause(TotalWaitTime)
 
                % Wait for camera to be idle.
                % If wait time > 100s then assume that something went wrong
                % - in this case:
                % 1. Write error to log file with available information
                % 2. Abort
                % 3. Restart instruments
                % 4. continue
                % ...
                [ready,Status]=Unit.readyToExpose('Itel',find(ListOfCams),...
                         'Wait',true,'Timeout',20);
                if ~ready
                    % be more specific in the message here, add which
                    % component failed
                    Unit.reportError('Unit didn''t finish exposure')
                    Mailbox.hset(requestHash,'Status','failed','JD',JD);
                else
                    Mailbox.hset(requestHash,'Status','observed','JD',JD);
                end

                % check seeing/focus of latest observations
                %   As a rule the camera object should calculate the
                %   FWHM, Elongation, Theta, MedBack for the last image in a
                %   sequence (only if the sequence length is >5).
                % FWHM [arcsec], Elongation [A/B], Theta [deg], MedBack
                % [DN; median background of image sample]
                %[FWHM, Elongation, Theta, MedBack] = ...
                % but for now we have only
                %  Unit.Camera{:}.classCommand('LastImageFWHM'), no moments

                % Write to log:
                % TextLog = sprintf('Sequence of %d images of %d [s]. Theta=5.1f  Elon=%5.1f  Theta=%6.1f',Nexp, ExpTime, FWHM, Elongation, Theta);  
                Unit.report('Sequence of %d images of %d [s]\n',Nexp, ExpTime);
                Unit.report('  Properties of the last images:\n')
                for i=find(ListOfCams)
                    Unit.report('Camera %d: FWHM %.3f\n',i,Unit.Camera{i}.classCommand('LastImageFWHM'))
                end
                
                % check mount temp/images/quality/seeing/smearing(!)??
                % Place holder for treating bad image quality

            else
                % No targets - this is a bug
                % writeLog
                ReportText = sprintf('No Target');
                Unit.report(ReportText);
                Unit.GeneralStatus = ReportText;
            end % if ~isempty(TargetInd)

        else
            Unit.report('Sun is too high!\n')
        end % if SunAlt<Args.SunMaxAlt
       
    end % while ContinueObs


    % if we got here, either we are done or the script was aborted
    if Unit.AbortActivity
        Unit.GeneralStatus='aborted: why, because';
        Unit.report([mfilename,' aborted'])
    else
        Unit.GeneralStatus='Observations terminated';
    end
