function operateUnit(Unit, ToFocus)
% Operate a single mount during a single night.
% Operate the cameras and focusers.
% Operating following a single ‘start’ command.
% Automatically calibrate the system (focus, pointing, flat, etc.)
% Do not focus if ToFocus = false;
% Observe different fields of view with different observing parameters according to a given input.
% Stop observations due to defined stopping criteria.
% Automatically solve basic problems.
% Keep a log.
%
% Written by David Polishook, Jan 2023

arguments
    Unit
    ToFocus = true;
end

RAD = 180./pi;
MaxConnectionTrials             = 3;
MinSunAltForFlat                = -8;    % degrees
MaxSunAltForFlat                = -2;    % degrees
MaxSunAltForObs                 = -12;   % degrees
MaxSunAltForFocus               = -9.5;    % degrees
FocusLogsDirectory              = '/home/ocs';
FocusDec                        = 60;    % degrees
FocusHA                         = 0;     % degrees
FocusLoopTimeout                = 300;   % 5 minutes
PauseTimeForTargetsAvailability = 5.*60; % sec
SlewingTimeout                  = 60;    % sec
CamerasToUse = zeros(1,4);


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
while (~RC && TrialsInx < MaxConnectionTrials)
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

% Send mount to home if at Park Position.
if (strcmp(Unit.Mount.Status,'disabled'))
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
    %fprintf(Sun.Alt)
    fprintf('Sun too high - wait, or use ctrl+c to stop the method\n')
    UnitObj.GeneralStatus='waiting for sunset';
    % Wait for 30 seconds
    pause(30);
    Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
end

% Take Flat Field.
if (Sun.Alt*RAD > MinSunAltForFlat && Sun.Alt*RAD < MaxSunAltForFlat)
    
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

    for IFocuser=[1 2 3 4]
        
        if Temp>35
            Unit.Camera{IFocuser}.classCommand('Temperature=5');
            fprintf('Setting the camera temperature to +5deg.\n')
        elseif Temp>30
            Unit.Camera{IFocuser}.classCommand('Temperature=0');
            fprintf('Setting the camera temperature to 0deg.\n')
        else
            Unit.Camera{IFocuser}.classCommand('Temperature=-5');
            fprintf('Setting the camera temperature to -5deg (default).\n')
        end
	end
 
    
    fprintf('Taking flats\n')
    Unit.takeTwilightFlats
else
    fprintf('Sun too low, skipping twilight flats\n')
end

% Run focus loop
if (ToFocus)
   % Check Sun altitude to know when to start focus loop
   Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
   while (Sun.Alt*RAD > MaxSunAltForFocus)
      fprintf('Sun too high to focus - wait, or use ctrl+c to stop the method\n')
      % Wait for 30 seconds
      pause(30);
      Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
   end
    
   % Send mount to meridian at dec 60 deg, to avoid moon.
   Unit.Mount.goToTarget(FocusHA,FocusDec,'ha')
   fprintf('Sent mount to focus coordinates\n')
   
   
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
   if (~(round(Unit.Mount.Dec,0) > FocusDec-1 && round(Unit.Mount.Dec,0) < FocusDec+1 && ...
         round(Unit.Mount.HA,0)  > FocusHA-1  && round(Unit.Mount.HA,0)  < FocusHA+1))
      fprintf('Mount failed to reach requested coordinates - abort (cable streaching issue?)\n');
      Unit.shutdown;
      return;
   end
    
   % Make a focus run
   FocusTelStartTime = celestial.time.julday;
   Unit.focusTel;
    
   % Wait for 1 minute before start checking if the focus run concluded
   pause(60)
    
   % Check the focusTel success
   for CameraInx=1:1:4
       CamerasToUse(CameraInx) = Unit.checkFocusTelSuccess(CameraInx, FocusTelStartTime, FocusLoopTimeout);
   end
   if(~prod(CamerasToUse))
       % Report the focus status
       fprintf('Focuser1 %d, Focuser2 %d, Focuser3 %d, Focuser4 %d\n', CamerasToUse)
   else
       fprintf('Focus succeeded for all 4 telescopes\n')
   end
   
else
   fprintf('Skip focus routine as requested\n')
end






% observe
%obs.util.observation.loopOverTargets(Unit,'NLoops',1,'CoordFileName','/home/ocs/target_coordinates_sne.txt')

if Unit.checkWholeUnit
    Unit.GeneralStatus='ready';
else
    Unit.GeneralStatus='not ready';
end

% Reached here, 7/03/2023
return %%%













T = celestial.Targets.createList('RA',[289.16 89.19 227.28 212.59].','Dec',[61.6,48.1,52.5,44.2].','MaxNobs',500);
T.write('~/Desktop/latetime_SNe.mat');
fprintf('Read target list\n')

[~,~,Ind] = T.calcPriority(2451545.5,'fields_cont');

%for I=1:1:length(T.RA)
%



% % Keep the last time of focusing separately for each telescope.
% UnitCS.LastFocusTime(1:4) = celestial.time.julday;
% UnitCS.LastFocusTemp(1:4) = XXX;
% 
% Start loop as long as run criteria are true
TargetListLoop = true;
TargetCounter = 0;

while(TargetListLoop)
   % Read targets.txt file
   T = celestial.Targets;
   % This line should be replaced with a proper T.readTargetList DP Mar 1, 2023
   T.generateTargetList('last');
   fprintf('Read target list\n')

   % Analize target file: decide coordinate shift, camera parameters.

   % This line should be replaced with T.calcPriority
   Ind = find(T.RA < 70 & T.RA > 60 & T.Dec > 40 & T.Dec < 50);
   if (isempty(Ind))
      % If failed to read target file run F6.
      fprintf('No visible targets - wait for 1 minute, or use ctrl+c to stop the method\n')
      pause(60);
   else
      % Send mount to coordinates.
      TargetCounter = TargetCounter + 1;
      if (TargetCounter <= length(Ind))
         RA = T.RA(Ind(TargetCounter));
         Dec = T.Dec(Ind(TargetCounter));
         % Send mount to coordinates.
         fprintf('Slew to target %d: %s\n', TargetCounter, T.TargetName{Ind(TargetCounter)})
         RC = Unit.Mount.goToTarget(RA,Dec);
   
         if (RC)
            % Take exposures
            CamerasToUse = [1,2,3,4]; % Temp
            ExpTime = 20; % seconds  % Temp
            ImNum = 2;               % Temp
            fprintf('Taking exposure, ExpTime=%.2f x ImNum=%d\n', ExpTime, ImNum)
            Unit.takeExposure(CamerasToUse, ExpTime, ImNum);
            ReadoutTime = 3;
            VisitPreparingTime = 20;
   
            % Pause for exposure
            pause(VisitPreparingTime+(ExpTime + ReadoutTime)*ImNum);
         end
      else
         fprintf('Target list was observed\n')
         return
      end
   end

      % Go to loop's start
      
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
end
% 
% % Save log
% Unit.SubmitLogReport
% 



