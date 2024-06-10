function operateUnit(Unit, Args)
% Purpose: perform all operations necessary to start operating an unit.
%          Connect hardware, check and attempt reconnection, take flats if
%          at twilight, focus the telescopes if it is dark enough
%
% [Observe different fields of view with different observing parameters
%  according to a given input.]
% Stop observations due to defined stopping criteria.
% Automatically solve basic problems.
% Keep a log.
%
% Default key-value arguments:
%
%     CamerasToUse                    = 1:numel(Unit.Camera);
%     MaxConnectionTrials             = 3;    % try to reconnect if not ready
%     Focus                           = true; % run focus loop after flats
%     MaxNumFlats                     = 20;
%     MinSunAltForFlat                = -8;    % degrees
%     MaxSunAltForFlat                = -2;    % degrees
%   %  MaxSunAltForObs                 = -12;   % degrees
%     MaxSunAltForFocus               = -9.5;    % degrees
%     FocusLogsDirectory              = '/home/ocs';
%     FocusDec                        = 60;    % degrees
%     FocusHA                         = 0;     % degrees
%     FocusLoopTimeout                = 300;   % 5 minutes
%   %  PauseTimeForTargetsAvailability = 5.*60; % sec
%     SlewingTimeout                  = 60;    % sec

% Written by David Polishook, Jan 2023
% Sanitization in progress by Enrico Segre, May 2024

arguments
    Unit
    Args.CamerasToUse                    = 1:numel(Unit.Camera);
    Args.SlewingTimeout                  = 60;    % sec
    Args.MaxConnectionTrials             = 2;
    Args.MinSunAltForFlat                = -8;    % degrees
    Args.MaxSunAltForFlat                = -2;    % degrees
    Args.MaxNumFlats                     = 20;
    Args.Focus = true;
    Args.MaxSunAltForFocus               = -9.5;    % degrees
    Args.FocusLogsDirectory              = '/home/ocs';
    Args.FocusDec                        = 60;    % degrees
    Args.FocusHA                         = 0;     % degrees
    Args.FocusLoopTimeout                = 300;   % 5 minutes
    % Args.PauseTimeForTargetsAvailability = 5.*60; % sec
    % Args.MaxSunAltForObs                 = -12;   % degrees
end

RAD = 180./pi;
UnitName=inputname(1);

Unit.GeneralStatus='Operation initialization';

% Connect the unit if not already connected. As indicator, check if Cameras
%  have a status. Debatable whether to use other indicators as well
disconnected=true;
for i=Args.CamerasToUse
    disconnected=disconnected & isempty(Unit.Camera{i}.classCommand('CamStatus'));
end
if disconnected
   Unit.connect;
else
   fprintf('Observing Unit is already connected\n')
end

% Check all systems (mount, cameras, focusers, computers, 
%   computer disk space(??)) are operating and ready.
RC = Unit.checkWholeUnit(0,1,Args.CamerasToUse);
TrialsInx = 1;
while (~RC && TrialsInx < Args.MaxConnectionTrials)
   % If failed, try to reconnect.
   TrialsInx = TrialsInx + 1;
   % fprintf('If failed, try to shutdown and reconnect\n');
   % Shutdown
   % Unit.shutdown
   % connect
   % Unit.connect
   fprintf('unit check failed, trying again\n');
   RC = Unit.checkWholeUnit(0,1,Args.CamerasToUse);
end

% Abort if failed
if (~RC)
   fprintf('Recurring connection problem - shutting down and aborting\n');
   Unit.shutdown;
   return;
end

fprintf('~~~~~~~~~~~~~~~~~~~~~\n\n')

% Send mount to home if at Home Position (actually, nowadays unnecessary)
Unit.GeneralStatus='homing mount';
if (strcmp(Unit.Mount.Status,'disabled'))
   Unit.Mount.home
   fprintf('Mount moves to home position\n')
   % Wait for slewing to complete
   Timeout = 0;
   while(Unit.Mount.isSlewing && Timeout < Args.SlewingTimeout && ~Unit.AbortActivity)
      pause(1);
      Timeout = Timeout + 1;
   end
   
   % Check home success:
   if (round(Unit.Mount.Alt,0) ~= 60 || round(Unit.Mount.Az,0) ~= 180)
      fprintf('Mount failed to reach home - abort (cable stretching issue?)\n');
      Unit.shutdown;
      return;
   end
end

% Track on.
Unit.Mount.track;
pause(1)
% Check success.
if (Unit.Mount.TrackingSpeed(1) == 0)
   fprintf('Mount failed to track - abort\n');
   Unit.shutdown;
   return;
end
fprintf('Mount is tracking\n')

% Read the Sun altitude.
M = Unit.Mount;
Lon = M.classCommand('MountPos(2)');
Lat = M.classCommand('MountPos(1)');
Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
% Decide if to run takeTwilightFlats
while (Sun.Alt*RAD > Args.MaxSunAltForFlat)  && ~Unit.AbortActivity
    %fprintf(Sun.Alt)
    fprintf('Sun at %.1f°, too high - wait, or use ctrl+c to stop the method\n',...
        Sun.Alt*RAD)
    Unit.GeneralStatus='waiting for sunset';
    % Wait for 30 seconds
    Unit.abortablePause(30);
    Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
end

% Take Flat Field.
if (Sun.Alt*RAD > Args.MinSunAltForFlat && Sun.Alt*RAD < Args.MaxSunAltForFlat) && ...
        ~Unit.AbortActivity
    Unit.GeneralStatus='setting camera temperatures';
    % increase chip temperature if it is too hot
    temp1 = Unit.PowerSwitch{1}.classCommand('Sensors.TemperatureSensors(1)');
    temp2 = Unit.PowerSwitch{2}.classCommand('Sensors.TemperatureSensors(1)');
    
    if temp1<-10
        Temp = temp2;
	elseif temp2<-10
        Temp = temp1;
    else
        Temp = (temp1+temp2)*0.5;
    end
	fprintf('\nThe temperature is %.1f deg.\n', Temp)

    for Icam=Args.CamerasToUse        
        if Temp>35
            CoolTemp=5;
        elseif Temp>30
            CoolTemp=0;
        else
            CoolTemp=-5;
        end
        Unit.Camera{Icam}.classCommand('Temperature=5;');
        fprintf('Setting camera %d temperature to +%.0f°\n',Icam,CoolTemp)
    end
   
    fprintf('Taking flats\n')
    Unit.takeTwilightFlats(Args.CamerasToUse,'MinSunAlt',Args.MinSunAltForFlat,...
                           'MaxSunAlt',Args.MaxSunAltForFlat,...
                           'MaxNumFlats',Args.MaxNumFlats);
else
    fprintf('Sun at %.1f°, too low, skipping twilight flats\n',Sun.Alt*RAD)
end

% Run focus loop
if (Args.Focus)  && ~Unit.AbortActivity
   Unit.GeneralStatus='focusing the telescopes';
   % Check Sun altitude to know when to start focus loop
   Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
   while (Sun.Alt*RAD > Args.MaxSunAltForFocus) && ~Unit.AbortActivity
      fprintf('Sun at %.1f°, too high to focus - wait, or use ctrl+c to stop the method\n',...
              Sun.Alt*RAD)
      Unit.GeneralStatus='waiting for dark to focus the telescopes';
      % Wait for 30 seconds
      Unit.abortablePause(30);
      Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
   end
   
   if Unit.AbortActivity
       Unit.GeneralStatus='taking darks aborted';
       Unit.abort(false);
       return
   end
   
   % Send mount to meridian at dec 60 deg, to avoid moon.
   Unit.Mount.goToTarget(Unit.Mount.LST-Args.FocusHA,Args.FocusDec);
   fprintf('Sent mount to focus coordinates\n')
   Unit.GeneralStatus='mount sent to focusing coordinates';
   
   % TODO: should try to run focusByTemperature for a better initial guess   
   %for IFocuser=[1,2,3,4]
   %    try
            % TODO: should try to run focusByTemperature for a
            % better initial guess
            %Unit.Slave(IFocuser).Messenger.send(['Unit.focusByTemperature(' num2str(IFocuser) ')']);
        % catch % won't work if last focus loop was not successful
        %end
   %end
   
   % Check success:
   DeltaHA = mod(Unit.Mount.HA - Args.FocusHA+180,360)-180;
   DeltaDec = Unit.Mount.Dec - Args.FocusDec;
   if abs(DeltaHA)>1 || abs(DeltaDec)>1
      fprintf('Mount delta =(%f,%f)\n',DeltaHA,DeltaDec);
      fprintf('Mount failed to reach requested coordinates (cable stretching issue?)\n');
      fprintf('Aborting\n')
      Unit.shutdown;
      return;
   end
    
   % Start focus run
   FocusTelStartTime = celestial.time.julday;
   Unit.focusTel(Args.CamerasToUse);
   
   % poll till end of focus loop on all slaves
   FocusInProgress=true;
   while ~FocusInProgress && ~Unit.AbortActivity
       % FIXME: dirty, identifying Slave # with telescope #, i.e. not right
       %  for configurations mixing local and remote telescopes
       FocusInProgress=false;
       for i=Args.CamerasToUse
           FocusInProgress = FocusInProgress || ...
              ~isempty(Unit.Slave(i).Responder.query('MasterMessenger.ExecutingCommand'));
          % if a slave times out, we get an empty reply too, and we
          %  consider the focus done, whithout checking further
       end
       Unit.abortablePause(5)
   end
   
   % take care to abort also the running focusTelInSlave on each slave, if
   %  Unit.AbortActivity was set true in the master
   if Unit.AbortActivity
       for i=Args.CamerasToUse
           Unit.Slave(i).Responder.send(sprintf('%s.AbortActivity=true;',UnitName));
       end
   end
   
   % Check the focusTel success
   FocusSucceded=false(1,numel(Unit.Camera));
   msg='focus loop:';
   for Icam=Args.CamerasToUse
       FocusSucceded(Icam) = Unit.checkFocusTelSuccess(Icam, FocusTelStartTime, Args.FocusLoopTimeout);
       if FocusSucceded(Icam)
           fprintf('Focusing telescope %d succeeded\n',Icam);
           msg=[msg, sprintf(' Tel.%d OK',Icam)];
       else
           fprintf('Focusing telescope %d FAILED!\n',Icam);
           msg=[msg, sprintf(' Tel.%d FAIL',Icam)];
       end           
   end
   Unit.GeneralStatus=msg; % (will this stay for long?)
   
else
   fprintf('Skipped focus routine, as requested\n')
end

% release the .AbortActivity flag, if was set true inbetween
Unit.abort(false);

if Unit.checkWholeUnit(false,false,Args.CamerasToUse)
    Unit.GeneralStatus='ready';
else
    Unit.GeneralStatus='not ready';
end

% at this point we're ready for observing. My understanding is that the
%  normal nightly workflow involves calling obs.util.obsByPtiority2 now