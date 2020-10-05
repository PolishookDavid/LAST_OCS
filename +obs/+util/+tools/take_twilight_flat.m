function take_twilight_flat(M,C,varargin)
% Obtain a series of twiligh flat images using a LAST pier system.
% Package: +obs.util.tools
% Description: Obtain a series of Twiligh flat images automatically. The
%              exposure time is selected based on sky brightness.
% Input  : -
% Output : -
%     By :
% Example: obs.util.tools.take_twilight_flat(M,C);


RAD = 180./pi;

InPar = inputParser;
addOptional(InPar,'MaxFlatLimit',40000);
addOptional(InPar,'MinFlatLimit',2000);
addOptional(InPar,'MinSunAlt',-10);
addOptional(InPar,'MaxSunAlt',-4);
addOptional(InPar,'ExpTimeRange',[3 15]);
addOptional(InPar,'TestExpTime',1);
addOptional(InPar,'MeanFun',@nanmedian);
addOptional(InPar,'EastFromZenith',20);
addOptional(InPar,'RandomShift',3);
addOptional(InPar,'ImType','SkyFlat');
addOptional(InPar,'WaitTimeCheck',30);
addOptional(InPar,'Verbose',true);
addOptional(InPar,'Plot',true);
parse(InPar,varargin{:});
InPar = InPar.Results;


 
    
Lon = M.MountPos(1);
Lat = M.MountPos(2);

% get Sun Altitude

Counter = 0;
I = 0;
AttemptTakeFlat = true;
while AttemptTakeFlat
    I = I + 1;
    
    Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);

    if exist('/home/eran/abort','file')
        AttemptTakeFlat = false;
    end
    
    if (Sun.Alt.*RAD)>InPar.MinSunAlt && (Sun.Alt.*RAD)<InPar.MaxSunAlt
        % take wilight test image and check that mean value is within allowed
        % range

        % set telescope pointing
        JD  = celestial.time.julday;  % current UTC JD
        LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg
        RA  = LST - 0;  % RA at HA=0
        RA  = RA + InPar.EastFromZenith;
        RA  = mod(RA,360);
        M.goto(RA,Lat);
        
        % take test image without saving to disk
        C.SaveOnDisk = false;
        C.ExpTime    = InPar.TestExpTime;
        C.takeExposure;
        C.waitFinish;
        C.SaveOnDisk = true;
        
        MeanValPerSec      = InPar.MeanFun(single(C.LastImage(:)))./InPar.TestExpTime;
        % expected mean value at min exp time
        MeanValAtMin = MeanValPerSec .* min(InPar.ExpTimeRange);
        MeanValAtMax = MeanValPerSec .* max(InPar.ExpTimeRange);

        if InPar.Verbose
            fprintf('Flat test image\n');
            fprintf('     SunAlt             : %5.2f\n',Sun.Alt.*RAD);
            fprintf('     Az                 : %6.2f\n',M.Az);
            fprintf('     Alt                : %6.2f\n',M.Alt);
            fprintf('     Image ExpTime      : %6.1f\n',InPar.TestExpTime);
            fprintf('     Image MeanValPerSec: %10.1f\n',MeanValPerSec);
        end
        
        
        if MeanValAtMax>InPar.MinFlatLimit && MeanValAtMin<InPar.MaxFlatLimit
            % Sun Altitude and image mean value are in allowed range
            % start twiligh flat sequemce

            % set ImType to flat
            C.ImType  = InPar.ImType;
            
            ContFlat = true;
            while ContFlat
                % take flat images
                Counter = Counter + 1;

                % set telescope pointing
                JD  = celestial.time.julday;  % current UTC JD
                LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg
                RA  = LST - 0;  % RA at HA=0
                RA  = RA + InPar.EastFromZenith;
                RA  = mod(RA,360);
                RA  = RA + (rand(1,1)-0.5).*2.*InPar.RandomShift;
                Dec = Lat + (rand(1,1)-0.5).*2.*InPar.RandomShift;
                M.goto(RA,Dec);
                M.waitFinish;
                
                EstimatedExpTime = InPar.MaxFlatLimit./MeanValPerSec;
                if EstimatedExpTime>min(InPar.ExpTimeRange) && EstimatedExpTime<max(InPar.ExpTimeRange)
                    C.ExpTime = EstimatedExpTime;

                    C.takeExposure;
                    C.waitFinish;
                    MeanValPerSec      = InPar.MeanFun(single(C.LastImage(:)))./EstimatedExpTime;

                    % expected mean value at min exp time
                    MeanValAtMin = MeanValPerSec .* min(InPar.ExpTimeRange);
                    MeanValAtMax = MeanValPerSec .* max(InPar.ExpTimeRange);

                    if InPar.Verbose
                        fprintf('Flat image number %d\n',Counter);
                        fprintf('     SunAlt             : %5.2f\n',Sun.Alt.*RAD);
                        fprintf('     Az                 : %6.2f\n',M.Az);
                        fprintf('     Alt                : %6.2f\n',M.Alt);
                        fprintf('     Image ExpTime      : %6.1f\n',InPar.TestExpTime);
                        fprintf('     Image MeanValPerSec: %10.1f\n',MeanValPerSec);
                    end
                    
                    if exist('/home/eran/abort','file')
                        ContFlat = false;
                    end
                end
                
                % get Sun altitude
                Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
                if MeanValAtMax>InPar.MinFlatLimit && MeanValAtMin<InPar.MaxFlatLimit && ...
                                                      (Sun.Alt.*RAD)>InPar.MinSunAlt && (Sun.Alt.*RAD)<InPar.MaxSunAlt && ...
                                                      EstimatedExpTime>min(InPar.ExpTimeRange) && EstimatedExpTime<max(InPar.ExpTimeRange)
                    ContFlat = true;
                else
                    ContFlat = false;
                end

                

                % check weather or abort commands
                % TBD
                
            end
        else
            pause(InPar.WaitTimeCheck);
            
        end

        if Counter>0
            AttemptTakeFlat = false;
        end

    else
        if InPar.Verbose
            fprintf('Not ready to start flat - SunAlt is not in range\n');
            fprintf('     SunAlt             : %5.2f\n',Sun.Alt.*RAD);
        end
        
        if Counter==0
            % else for (Sun.Alt.*RAD)>InPar.MinSunAlt && (Sun.Alt.*RAD)<InPar.MaxSunAlt
            pause(InPar.WaitTimeCheck);
        end
    end
end
    
% returm ImType to default value
C.ImType = 'science';
    