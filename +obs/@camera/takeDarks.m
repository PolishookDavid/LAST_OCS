function takeDarks(C,varargin)
% Take a sequence of dark images
% FIXME - NEEDS TO BE REDONE ACCORDING TO THE mastrolindo changes

InPar = inputParser;
addOptional(InPar,'ExpTime',15);    % vector of ExpTime
addOptional(InPar,'Ndark',10);  
addOptional(InPar,'Temp',-8);    % vector of temperatures
addOptional(InPar,'MaxTempDiff',2);    % vector of temperatures
addOptional(InPar,'WaitTempTimeout',120);    % [s]
addOptional(InPar,'ImType','dark');    % [s]
addOptional(InPar,'Verbose',true);
parse(InPar,varargin{:});
InPar = InPar.Results;

C.SaveOnDisk = true;

Nexp  = numel(InPar.ExpTime);
Ntemp = numel(InPar.Temp);

for Itemp=1:1:Ntemp
    Temp = InPar.Temp(Itemp);
    C.Temperature = Temp;
    % wait for temperature to stablize
    WaitTemp = true;
    % need to put a loop here
    %pause(WaitTempTimeout);
    
    CoolingPower = C.CoolingPower;
    if abs(C.Temperature-Temp)<InPar.MaxTempDiff && CoolingPower<100
        % ok to continue
    
        C.ImType = InPar.ImType;
        for Iexp=1:1:Nexp
            C.ExpTime = InPar.ExpTime(Iexp);

            for Idark=1:1:InPar.Ndark

                if InPar.Verbose
                    fprintf('Take dark exposure\n');
                    fprintf('   Requested Temp : %f\n',Temp);
                    fprintf('   Actual Temp    : %f\n',C.Temperature);
                    fprintf('   ExpTime        : %f\n',InPar.ExpTime(Iexp));
                    fprintf('   Temp seq %d, Exp seq %d, Image %d\n',Itemp,Iexp,Idark);
                end

                C.takeExposure;
                C.waitFinish;
            end
        end
    else
        if InPar.Verbose
            fprintf('Temperature did not reach destination\n');
        end            
    end
end

% return to default values
C.ImType = 'science';

