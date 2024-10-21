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

        Args.SelectMethod    = 'minam';

        Args.CameraTempFunction % left empty, because the default can't be built in the arguments block 
        Args.CheckAbortTime     = 10;  % [s] when taking exposure, will check for abort every THIS number of seconds
        

        Args.SimulationJD   = [];   % if given, then work in simulation mode
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

    %=== SCHEDULER ===
    % Define a populate the reference class:
    TS = telescope.Scheduler;
    TS.GeoPos = Args.GeoPos;
    % Read target list
    % ... Eran will provide
    % Idea - inspect a preset Redis key
    
    % If target list is not available or empty, then create default list:
    if isempty(TS) || isempty(TS.List) % is there another condition for empty list?
        TS.generateRegularGrid('ListName','LAST', 'N_LonLat',[88 30]);
    end

    % Check hardware status
    %   Check mount connected, no faults
    % ...
    %   If needed fix problems
    % ...
    %   DONOT set mount to home position
    %   Check cameras and focusers
    [~,~,ListOfCams] = Unit.checkWholeUnit;  % vector operational camera+focuser

    if numel(find(ListOfCams))<Args.MinNumCamToUse
        abortActivityAndReport(Unit, sprintf('only %d cameras are available',numel(find(ListOfCams))));
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

    % Check that cameras Idle

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
            
        [SunAz, SunAlt, DSunAz, DSunAlt] = TS.sun(JD);


        if Unit.AbortActivity
            abortActivityAndReport(Unit);  % NOTE: abortActivity is an internal function
            return;
        end

        if SunAlt<Args.SunMaxAlt
            % can observe
            
            
            %=== select targets ===

            % initiate nightly counter (if needed)
            TS.initNightCounter(false);  % init NightCounter only if a new night

            % reload target list updates
            % ... from Eran

            % select target
            tic;
            [TargetInd, Priority, ~, TargetStruct] = TS.selectTarget(JD, 'MountNum',Unit.MountNumber, 'SelectMethod',Args.SelectMethod);
            RunTime = toc;
            ReportText = sprintf('Target selection run time: %f seconds',RunTime);
            Unit.report(ReportText);

            if ~isempty(TargetInd)
                % Traget selected

                ExpTime = TargetStruct.ExpTime;   % Requested ExpTime [s]
                Nexp    = TargetStruct.Nexp;      % Requested number of images

                % go to target
                % ...

                % Checks (either specifically, or using LastErr)
                %   check for mount faults
                %   check tracking
                %   check pointing
                % If checks failed - try to recover by calling mountRecover
                % function

                % takeExposure
                Unit.takeExposure(find(ListOfCams),ExpTime,Nexp)

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
                end

                % check seeing/focus of latest observations
                %   As a rule the camera object should calculate the
                %   FWHM, Elongation, Theta, MedBack for the last image in a
                %   sequence (only if the sequence length is >5).
                % FWHM [arcsec], Elongation [A/B], Theta [deg], MedBack
                % [DN; median background of image sample]
                [FWHM, Elongation, Theta, MedBack] =

                % Write to log:
                TextLog = sprintf('Sequence of %d images of %d [s]. Theta=5.1f  Elon=%5.1f  Theta=%6.1f',Nexp, ExpTime, FWHM, Elongation, Theta);
  
                Unit.report(TextLog);

                % update scheduler counters
                TS.increaseCounter(TargetInd);

                % check mount temp/images/quality/seeing/smearing(!)??
                % Place holder for treating bad image quality

            else
                % No targets - this is a bug
                % writeLog
                ReportText = sprintf('No Target');
                Unit.report(ReportText);
                Unit.GeneralStatus = ReportText;
            end % if ~isempty(TargetInd)


        end % if SunAlt<Args.SunMaxAlt
       
    end % while ContinueObs


end

if Unit.AbortActivity
    Unit.GeneralStatus='aborted, because';
    Unit.report([mfilename,' aborted'])
end
