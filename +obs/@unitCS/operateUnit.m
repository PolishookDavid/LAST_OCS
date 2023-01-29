function operateUnit(Unit)
% Operate a single mount during a single night.
% Operate the cameras and focusers.
% Operating following a single ‘start’ command.
% Automatically calibrate the system (focus, pointing, flat, etc.)
% Observe different fields of view with different observing parameters according to a given input.
% Stop observations due to defined stopping criteria.
% Automatically solve basic problems.
% Keep a log.
%
% Written by David Polishook, Jan 2023

arguments
    Unit
end

RAD = 180./pi;
MaxConnectionTrials             = 3;
MinSunAltForFlat                = -8;    % degrees
MaxSunAltForFlat                = -2;    % degrees
MaxSunAltForObs                 = -12;   % degrees
MaxSunAltForFocus               = -9;    % degrees
FocusLogsDirectory              = '/home/ocs';
FocusDec                        = 60;    % degrees
FocusHA                         = 0;     % degrees
FocusLoopTimeout                = 300;   % 5 minutes
PauseTimeForTargetsAvailability = 5.*60; % sec
SlewingTimeout                  = 60;    % sec


% Connect the mount.
Unit.connect

% No need to wait

% Check all systems (mount, cameras, focusers, computers, computer disk space) are operating and ready.
RC = Unit.checkWholeUnit(0,1);
TrialsInx = 1;
while (~RC && Unit.MountlsInx < MaxConnectionTrials)
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

% Send mount to home.
Unit.Mount.home
fprintf('Mount moves to home position\n')
% Wait for slewing to complete
Timeout = 0;
while(Unit.Mount.isSlewing && Timeout < SlewingTimeout)
   pause(1);
   Timeout = Timeout + 1;
end

% Check home success:
if (round(Unit.Mount.Alt,0) ~= 60 || round(Unit.Mount.Az,0) ~= 180)
   fprintf('Mount failed to reach home - abort (cable streaching issue?)\n');
   Unit.shutdown;
   return;
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
while (Sun.Alt*RAD > MaxSunAltForFlat)
   fprintf('Sun too high - wait, or use ctrl+c to stop the method\n')
   % Wait for 30 seconds
   pause(30);
   Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
end

% Take Flat Field.
if (Sun.Alt*RAD > MinSunAltForFlat && Sun.Alt*RAD < MaxSunAltForFlat)
   fprintf('Taking flats\n')
   Unit.takeTwilightFlats
end

% Continue with the observation.

% Send mount to meridian at dec 60 deg, to avoid moon.
Unit.Mount.goToTarget(FocusHA,FocusDec,'ha')

% Check success:
if (~(round(Unit.Mount.Dec,0) > FocusDec-1 && round(Unit.Mount.Dec,0) < FocusDec+1 && ...
    round(Unit.Mount.HA,0)  > FocusHA-1  && round(Unit.Mount.HA,0)  < FocusHA+1))
   fprintf('Mount failed to reach requested coordinates - abort (cable streaching issue?)\n');
   Unit.shutdown;
   return;
end


% Run focus loop
% Check Sun altitude to know when to start focus loop
Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
while (Sun.Alt*RAD > MaxSunAltForFocus)
   fprintf('Sun too high - wait, or use ctrl+c to stop the method\n')
   % Wait for 30 seconds
   pause(30);
   Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
end
% Make a focus run
FocusloopStartTime = celestial.time.julday;
Unit.focusTel;

% Wait for 1 minute before start checking if the focus run concluded
pause(60)

% Check the focusTel success
CamerasToUse = zeros(1,4);
for CameraInx=1:1:4
   CamerasToUse(CameraInx) = Unit.checkFocusTelSuccess(CameraInx, FocusLoopTimeout);
end
if(~prod(CamerasToUse))
      % Report the focus status
   fprintf('Focuser1 %d, Focuser2 %d, Focuser3 %d, Focuser4 %d\n', CamerasToUse)
else
   fprintf('Focus succeeded for all 4 telescopes\n')
end



% Reached here, 25/01/2023
return %%%


% % Keep the last time of focusing separately for each telescope.
% UnitCS.LastFocusTime(1:4) = celestial.time.julday;
% UnitCS.LastFocusTemp(1:4) = XXX;
% 
% % Start loop as long as run criteria are true
% TargetListLoop = true;
% 
% While(TargetListLoop)
% 
%    % Read targets.txt file
%    % Analize target file: decide coordinate shift, camera parameters.
%    RC = Unit.analyzeTargetList;
%    if (~RC)
%       % If failed to read target file run F6.
%    end
%    
%    % Check if the targets are observable.
%    [RA, Dec, Cameras, ExpTime, ImNum] = Unit.checkTargetAvailability;
% 
%    % If no target matches the conditions, wait for 10 minutes and go to the loop’s start.
%    while (isemprty(RA))
%       pause(PauseTimeForTargetsAvailability)
%       [RA, Dec, Cameras, ExpTime, ImNum] = Unit.checkTargetAvailability;
%       
%    end
%    
%    % Send mount to coordinates.
%    Unit.Mount.goToTarget(RA,Dec);
% 
%    % Pause for slewing
% 
%    % Check Astrometry
%    RC = Unit.checkAstrometry;
%       
%    if (~RC)
%       % If failed, run F7.
%    end
%       
%    % Take exposures.
%    Unit.takeExposure(CamerasToUse, ExpTime, ImNum);
%       
%    % Pause for exposure
%       
%    % Check images are being taken with usable quality, while taking exposures.
%    Unit.checkSequence
% 
%    if (~RC)
%       % If failed, run F8.
%    end
%       
%    % Pause until the sequence (ExpTime x ImNum) is done. Use: UnitCS.waitTilFinish
% 
% 
%    % Keep track for cycle number being taken: UnitCS.TargetCycle(Index)=+1
% 
%    % Check if to shutdown due to sunrise, by checking the Sun altitude.
%    Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
%    if (Sun.Alt*RAD > MaxSunAltForObs)
%       TargetListLoop = false;
%       UnitCS.shutdown
%       % Pause for shutdown
%       pause()
%    else
%       % If Sun is low enough: continue the loop.
%       
%       % Check if to redo focus by comparing current temperature to UnitCS.LastFocusTemp(1:4).
%       % Calculate new focus by temperature change
% 
%       % Go to loop’s beginning.
%    end
% end
% 
% % Save log
% Unit.SubmitLogReport
% 



