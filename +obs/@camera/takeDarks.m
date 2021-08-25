function takeDarks(C,varargin)
% Take a sequence of dark images
%
% Input arguments: key-value pairs including:
%   - 'ExpTime'          vector of exposure time(s) [default 15(sec)]
%   - 'Ndark'            number of dark images to take at each step [10]
%   - 'Temp'             vector of temperatures (default [-8])
%   - 'MaxTempDiff'      temperature difference from target tolerated [2]
%   - 'WaitTempTimeout'  maximum waiting time for temperature stabilization [120(sec)]
%   - 'ImType'           label type of the images ['dark']
%
% Output: none from the method, but resulting images are saved on disk
%
% FIXME - NEEDS TO BE REDONE ACCORDING TO THE mastrolindo changes
%
% Since I don't think that this method should be called in parallel
%  for all cameras of a unit, it stays a camera method.
% I assume that the typical use case would be bench characterization of
%  capped cameras, when disconnected from telescopes, and not a part
%  of the unitCS scheduled operation.
%  
% delicate point here: should we use live sequences, for Ndark>1 &&
%   ExpTime>5

InPar = inputParser;
addOptional(InPar,'ExpTime',15);    % vector of ExpTime(s)
addOptional(InPar,'Ndark',10);   % number of dark images to take at each step
addOptional(InPar,'Temp',-8);    % vector of temperatures
addOptional(InPar,'MaxTempDiff',2);    % vector of temperatures
addOptional(InPar,'WaitTempTimeout',120);    % [s]
addOptional(InPar,'ImType','dark');    % [s]
parse(InPar,varargin{:});
InPar = InPar.Results;

C.classCommand('SaveOnDisk = true;');

Nexp  = numel(InPar.ExpTime);
Ntemp = numel(InPar.Temp);

for Itemp=1:Ntemp
    targetTemp = InPar.Temp(Itemp);
    C.classCommand(['Temperature =' num2str(targetTemp) ';']);
    % wait for temperature to stablize
    t0=now;
    while (now-t0)*86400 < InPar.WaitTempTimeout
        pause(2)
        CoolingPower = C.classCommand('CoolingPower;');
        cameraTemperature=C.classCommand('Temperature;');
        C.report(sprintf('   Requested Temp : %f, Actual Temp    : %f\n',...
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
            C.classCommand(['ExpTime =' num2str(ExpTime) ';']);
            C.report('Taking dark exposure(s)\n');
            C.report(sprintf('   ExpTime        : %f\n',ExpTime));
            if InPar.Ndark>1 && ExpTime>5 % 5 sec to account for reading and saving overheads
                C.classCommand(['takeLive(' num2str(InPar.Ndark) ');']);
            else
                C.classCommand('takeExposure;');
            end
            % wait for finish in a decent way. FIXME!
            status='exposing';
            while strcmp(status,{'exposing','reading'})
                status=C.classCommand('CamStatus;');
            end
            if strcmp(status,'unknown')
                C.reportError('camera gone fishing!')
                break
            end
        end
    else
        C.reportError(sprintf('Temperature did not reach the target of %f.1°C',...
                               targetTemp));
    end
end

% return to default values
C.ImType = 'science';

