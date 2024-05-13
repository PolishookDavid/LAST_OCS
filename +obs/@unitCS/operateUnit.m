function operateUnit(Unit, Args)
% Operate a single mount during a single night.
% Operate the cameras and focusers.
% Operating following a single ‘start’ command.
% Automatically calibrate the system (focus, pointing, flat, etc.)
% Do not focus if Args.Focus = false;
% Observe different fields of view with different observing parameters according to a given input.
% Stop observations due to defined stopping criteria.
% Automatically solve basic problems.
% Keep a log.
%
% Written by David Polishook, Jan 2023
% Sanitization in progress by Enrico Segre, May 2024

arguments
    Unit
    Args.Focus = true;
    Args.MaxConnectionTrials             = 3;
    Args.MinSunAltForFlat                = -8;    % degrees
    Args.MaxSunAltForFlat                = -2;    % degrees
    Args.MaxSunAltForObs                 = -12;   % degrees
    Args.MaxSunAltForFocus               = -9.5;    % degrees
    Args.FocusLogsDirectory              = '/home/ocs';
    Args.FocusDec                        = 60;    % degrees
    Args.FocusHA                         = 0;     % degrees
    Args.FocusLoopTimeout                = 300;   % 5 minutes
    Args.PauseTimeForTargetsAvailability = 5.*60; % sec
    Args.SlewingTimeout                  = 60;    % sec
    Args.CamerasToUse                    = 1:numel(Unit.Camera);
end

RAD = 180./pi;

Unit.GeneralStatus='Operation initialization';

% Connect the mount if already connected.
RC1=Unit.Camera{1}.classCommand('CamStatus');
RC2=Unit.Camera{2}.classCommand('CamStatus');
RC3=Unit.Camera{3}.classCommand('CamStatus');
RC4=Unit.Camera{4}.classCommand('CamStatus');
if(isempty(RC1) && isempty(RC2) && isempty(RC3) && isempty(RC4))
   Unit.connect
else
   fprintf('Observing Unit is already connected\n')
end

% No need to wait

% Check all systems (mount, cameras, focusers, computers, computer disk space) are operating and ready.
RC = Unit.checkWholeUnit(0,1);
TrialsInx = 1;
while (~RC && TrialsInx < Args.MaxConnectionTrials)
   % If failed, try to reconnect.
   TrialsInx = TrialsInx + 1;
   fprintf('If failed, try to shutdown and reconnect\n');
   % Shutdown
   Unit.shutdown
   % connect
   Unit.connect
   RC = Unit.checkWholeUnit(0,1);
end

% Abort if failed
if (~RC)
   fprintf('A reoccuring connection problem - abort\n');
   Unit.shutdown;
   return;
end

fprintf('~~~~~~~~~~~~~~~~~~~~~\n\n')

% Send mount to home if at Park Position (actually, nowadays unnecessary)
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
if (Sun.Alt*RAD > Args.MinSunAltForFlat && Sun.Alt*RAD < Args.MaxSunAltForFlat)
    
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
            Unit.Camera{Icam}.classCommand('Temperature=5');
            fprintf('Setting the camera temperature to +5deg.\n')
        elseif Temp>30
            Unit.Camera{Icam}.classCommand('Temperature=0');
            fprintf('Setting the camera temperature to 0deg.\n')
        else
            Unit.Camera{Icam}.classCommand('Temperature=-5');
            fprintf('Setting the camera temperature to -5deg (default).\n')
        end
    end
   
    fprintf('Taking flats\n')
    Unit.takeTwilightFlats
else
    fprintf('Sun at %.1f°, too low, skipping twilight flats\n',Sun.Alt*RAD)
end

% Run focus loop
if (Args.Focus)
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
    
   % Send mount to meridian at dec 60 deg, to avoid moon.
   Unit.Mount.goToTarget(Args.FocusHA,Args.FocusDec,'ha')
   fprintf('Sent mount to focus coordinates\n')
   Unit.GeneralStatus='mount sent to focusing coordinates';
   
   % TODO: should try to run focusByTemperature for a better initial guess   
   %for IFocuser=[1,2,3,4]
   %    try
            % TODO: should try to run focusByTemperature for a
            % better initial guess
            %Unit.Slave{IFocuser}.Messenger.send(['Unit.focusByTemperature(' num2str(IFocuser) ')']);
        % catch % won't work if last focus loop was not successful
        %end
   %end
    
   
   % Check success:
   if (~(round(Unit.Mount.Dec,0) > Args.FocusDec-1 && round(Unit.Mount.Dec,0) < Args.FocusDec+1 && ...
         round(Unit.Mount.HA,0)  > Args.FocusHA-1  && round(Unit.Mount.HA,0)  < Args.FocusHA+1))
      fprintf('Mount failed to reach requested coordinates - abort (cable stretching issue?)\n');
      Unit.shutdown;
      return;
   end
    
   % Make a focus run
   FocusTelStartTime = celestial.time.julday;
   Unit.focusTel(Args.CamerasToUse);
    
   % Wait for 1 minute before start checking if the focus run concluded
   Unit.abortablePause(60)
    
   % Check the focusTel success
   FocusSucceded=false(1,numel(Unit.Camera));
   for Icam=Args.CamerasToUse
       FocusSucceded(Icam) = Unit.checkFocusTelSuccess(Icam, FocusTelStartTime, Args.FocusLoopTimeout);
       if FocusSucceded(Icam)
           fprintf('Focusing telescope %d succeeded\n',Icam);
       else
           fprintf('Focusing telescope %d FAILED!\n',Icam);
       end           
   end
   
else
   fprintf('Skip focus routine as requested\n')
end


if Unit.checkWholeUnit
    Unit.GeneralStatus='ready';
else
    Unit.GeneralStatus='not ready';
end

% at this point we're ready for observing. My understanding is that the
%  normal nightly workflow involves calling obs.util.obsByPtiority2 now