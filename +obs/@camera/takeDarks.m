function takeDarks(C,varargin)
% Take a sequence of dark images
%
% Input arguments: key-value pairs including:
%   - 'ExpTime'          vector of exposure time(s) [default 15(sec)]
%   - 'Ndark'            number of dark images to take at each step [10]
%   - 'Temp'             vector of temperatures (default [-8])
%   - 'MaxTempDiff'      temperature difference from target tolerated [2]
%   - 'WaitTempTimeout'  maximum waiting time for temperature stabilization [180(sec)]
%   - 'ImType'           label type of the images ['dark']
%
% Output: none from the method, but resulting images are saved on disk
%   to a service directory, sprcified in the configuration (Config.DarkDBDir)
%
% Since I don't think that this method should be called in parallel
%  for all cameras of a unit, it stays a camera method. Therefore,
%  I use .waitFinish without concern for messenger timeouts.
% I assume that the typical use case would be bench characterization of
%  capped cameras, when disconnected from telescopes, and not a part
%  of the unitCS scheduled operation. Nevertheless, better to
%  turn temporarily off SaveOnDisk, because if this method is called
%  on a camera inserted in a unit, we don't additionally want the unit
%  callback to save the image as science image.
%  
% delicate point here: should we use live sequences, for Ndark>1 &&
%   ExpTime>5

%  FIXME: how do we save automatically during a live sequence?
%  do we temporarily turn on a listener on LastImage? But then we'll want
%  to disarm that of the unit, if it exists. Do we use the former idea of 
%  ImageHandler? A mess.
% CameraObj.saveCurImage(CameraObj.Config.DarkDBDir)


InPar = inputParser;
addOptional(InPar,'ExpTime',15);
addOptional(InPar,'Ndark',10);
addOptional(InPar,'Temp',-8);
addOptional(InPar,'MaxTempDiff',2);
addOptional(InPar,'WaitTempTimeout',180);
addOptional(InPar,'ImType','dark');
parse(InPar,varargin{:});
InPar = InPar.Results;

Nexp  = numel(InPar.ExpTime);
Ntemp = numel(InPar.Temp);

saving=C.SaveOnDisk;
C.SaveOnDisk=false;

for Itemp=1:Ntemp
    targetTemp = InPar.Temp(Itemp);
    C.Temperature = targetTemp;
    % wait for temperature to stablize
    t0=now;
    while (now-t0)*86400 < InPar.WaitTempTimeout
        pause(2)
        CoolingPower = C.CoolingPower;
        cameraTemperature=C.Temperature;
        C.report(sprintf('   Requested Temperature : %.1f°C, Actual : %.1f°C\n',...
                         targetTemp,cameraTemperature));
        if abs(cameraTemperature-targetTemp)<InPar.MaxTempDiff
            break
        end
    end
    
    if abs(cameraTemperature-targetTemp)<InPar.MaxTempDiff
        % && CoolingPower<100 % Are we concerned, if cooling power is max?
        % ok to continue
        C.ImType = InPar.ImType;
        for Iexp=1:Nexp
            ExpTime=InPar.ExpTime(Iexp);
            C.ExpTime = ExpTime;
            C.report(sprintf('Taking %d dark exposure(s) of %g sec at T=%.1f°C\n',...
                             InPar.Ndark,ExpTime,C.Temperature));
            if false && InPar.Ndark>1 && ExpTime>5 %% FIXME when we can save 
                C.takeLive(InPar.Ndark);
                % saving is missing here yet
                C.waitFinish
            else
                for Idark=1:InPar.Ndark
                    C.takeExposure;
                    C.waitFinish;
                    C.saveCurImage(C.Config.DarkDBDir)
                end
            end
        end
    else
        C.reportError(sprintf('Temperature did not reach the target of %.1f°C',...
                               targetTemp));
    end
end

% restore default values
C.ImType = 'science';
C.SaveOnDisk = saving;


