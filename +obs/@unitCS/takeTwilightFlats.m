function takeTwilightFlats(UnitObj,itel,varargin)
%
% Obtain a series of twiligh flat images using a LAST pier system.
% Package: +obs.unitCS
% Description: Obtain a series of Twiligh flat images automatically. The
%              exposure time is selected based on sky brightness.
% Input  : - indices of cameras to operate ([]=all)
%          - optional key - values:
%               'MaxFlatLimit'   [40000]
%               'MinFlatLimit'   [2000]
%               'MinSunAlt'      [-10]
%               'MaxSunAlt'      [-4]
%               'ExpTimeRange    [3 15]
%               'TestExpTime'    [1]
%               'MeanFun'        [nanmedian] ** use string, not handle,
%                                            ** eval() in slave
%               'EastFromZenith' [20]
%               'RandomShift'    [3]
%               'ImType'         ['SkyFlat']
%               'WaitTimeCheck'  [30]
%               'Plot'           true
%
% Output : - none, but flat images are saved on disk, TODO in the directories
%  specified by each camera's Config.FlatDBDir
%     By :
% Example: P.take_twilight_flat();

if ~exist('itel','var')
    itel=[];
end
if isempty(itel)
    itel=1:numel(UnitObj.Camera);
end
Ncam=numel(itel);

InPar = inputParser;
addOptional(InPar,'MaxFlatLimit',40000);
addOptional(InPar,'MinFlatLimit',2000);
addOptional(InPar,'MinSunAlt',-10);
addOptional(InPar,'MaxSunAlt',-4);
addOptional(InPar,'ExpTimeRange',[3 15]);
addOptional(InPar,'TestExpTime',1);
addOptional(InPar,'MeanFun','nanmedian');
addOptional(InPar,'EastFromZenith',20);
addOptional(InPar,'RandomShift',3);
addOptional(InPar,'ImType','skyflat');
addOptional(InPar,'WaitTimeCheck',30);
addOptional(InPar,'Plot',true);
parse(InPar,varargin{:});
InPar = InPar.Results;
    
RAD = 180./pi;

M=UnitObj.Mount;
C=UnitObj.Camera(itel);

% store the present status of SaveOnDisk for each camera. We will save
%  images, but use an explicit call in order to provide the path, with
%  SaveOnDisk=false
saving=false(1,Ncam);
for icam=1:Ncam
    saving(icam)=C{icam}.classCommand('SaveOnDisk;');
    C{icam}.classCommand('SaveOnDisk = false;');
end


Lon = M.classCommand('MountPos(1)');
Lat = M.classCommand('MountPos(2)');

% get Sun Altitude

MeanValPerSec=nan(1,Ncam);
Counter = 0;
I = 0;
AttemptTakeFlat = true;
while AttemptTakeFlat
    I = I + 1;
    
    Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);

    if exist('/home/eran/abort','file') % FIXME !
        break
    end
    
    if (Sun.Alt*RAD)>InPar.MinSunAlt && (Sun.Alt*RAD)<InPar.MaxSunAlt
        % take twilight test image and check that mean value is within allowed
        %  range

        % set telescope pointing
        JD  = celestial.time.julday;  % current UTC JD
        LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg
        RA  = LST - 0;  % RA at HA=0
        RA  = RA + InPar.EastFromZenith;
        RA  = mod(RA,360);
        M.classCommand(sprintf('goTo(%f,%f);',RA,Lat));
        
        % take test image without saving to disk
        UnitObj.takeExposure(itel,InPar.TestExpTime);
        UnitObj.readyToExpose(itel);
        for icam=1:Ncam
            % compute mean of the image taken (remotely if the camera is remote)
            if isa(C{icam},'obs.remoteClass')
                % TODO check if ok with @ in string
                ImageMean=C{icam}.Messenger.query(sprintf('%s(single(%s.LastImage(:)))',...
                                                     InPar.MeanFun,C{icam}.RemoteName));
                MeanValPerSec(icam) = ImageMean/InPar.TestExpTime;
            else
                MeanValPerSec(icam) = InPar.MeanFun(single(C.LastImage(:)))/InPar.TestExpTime;
            end
        end
        
        % expected mean value at min exp time [FIXME: should we take the
        %    mean of all camera values, or what?]
        MeanValAtMin = mean(MeanValPerSec) * min(InPar.ExpTimeRange);
        MeanValAtMax = mean(MeanValPerSec) * max(InPar.ExpTimeRange);

        UnitObj.report('Flat test image\n');
        UnitObj.report(sprintf('    SunAlt              : %6.2f\n',Sun.Alt.*RAD));
        UnitObj.report(sprintf('    Az                  : %6.2f\n',M.classCommand('Az')));
        UnitObj.report(sprintf('    Alt                 : %6.2f\n',M.classCommand('Alt')));
        UnitObj.report(sprintf('    Image ExpTime       : %5.1f\n',InPar.TestExpTime));
        UnitObj.report(sprintf('    Image MeanValPerSec : %5.1f\n',mean(MeanValPerSec)));
               
        if MeanValAtMax>InPar.MinFlatLimit && MeanValAtMin<InPar.MaxFlatLimit
            % Sun Altitude and image mean value are in allowed range
            % start twilight flat sequemce

            % set ImType to flat
            C{icam}.classCommand(['ImType =''' InPar.ImType ''';']);
            
            ContFlat = true;
            while ContFlat
                % take flat images
                Counter = Counter + 1;

                % set telescope pointing
                JD  = celestial.time.julday;  % current UTC JD
                LST = celestial.time.lst(JD,Lon/RAD,'a').*360;  % deg
                RA  = LST - 0;  % RA at HA=0
                RA  = RA + InPar.EastFromZenith;
                RA  = mod(RA,360);
                RA  = RA + (rand(1,1)-0.5).*2.*InPar.RandomShift;
                Dec = Lat + (rand(1,1)-0.5).*2.*InPar.RandomShift;
                M.classCommand(sprintf('goTo(%f,%f);',RA,Dec));
                UnitObj.readyToExpose(itel,true);
                
                EstimatedExpTime = InPar.MaxFlatLimit/mean(MeanValPerSec);
                UnitObj.report(sprintf('Estimated exposure time: %g sec\n',...
                                        EstimatedExpTime));
                if EstimatedExpTime>min(InPar.ExpTimeRange) &&...
                        EstimatedExpTime<max(InPar.ExpTimeRange)
 
                    % this is almost the same code as above @line 95...
                    %  should be factorized!
                    UnitObj.takeExposure(itel,EstimatedExpTime);
                    UnitObj.readyToExpose(itel);
                    
                    for icam=1:Ncam
                        % save the images to the service directories
                        % BUG - passes 'UnitObj' instead of the true pier
                        %       object name
                        UnitObj.saveCurImage(itel(icam),...
                                  C{icam}.classCommand('Config.FlatDBDir'))
                        % compute the mean of the image taken (remotely if the camera is remote)
                        if isa(C{icam},'obs.remoteClass')
                            % TODO check if ok with @ in string
                            ImageMean=C{icam}.Messenger.query(sprintf('%s(single(%s.LastImage(:)))',...
                                InPar.MeanFun,C{icam}.RemoteName));
                            MeanValPerSec(icam) = ImageMean/EstimatedExpTime;
                        else
                            MeanValPerSec(icam) = InPar.MeanFun(single(C.LastImage(:)))/EstimatedExpTime;
                        end
                    end
                    
                    % expected mean value at min exp time [FIXME: should we take the
                    %    mean of all camera values, or what?]
                    MeanValAtMin = mean(MeanValPerSec) * min(InPar.ExpTimeRange);
                    MeanValAtMax = mean(MeanValPerSec) * max(InPar.ExpTimeRange);
                                        
                    UnitObj.report(sprintf('Flat image number %d\n',Counter));
                    UnitObj.report(sprintf('     SunAlt             : %5.2f\n',Sun.Alt.*RAD));
                    UnitObj.report(sprintf('     Az                 : %6.2f\n',M.classCommand('Az')));
                    UnitObj.report(sprintf('     Alt                : %6.2f\n',M.classCommand('Alt')));
                    UnitObj.report(sprintf('     Image ExpTime      : %6.1f\n',InPar.TestExpTime));
                    UnitObj.report(sprintf('     Image MeanValPerSec: %10.1f\n',mean(MeanValPerSec)));
                    
                    if exist('/home/eran/abort','file') % FIXME !!!!
                        ContFlat = false; % why value unused anyway?
                    end
                else
                    UnitObj.report(sprintf('Estimated exposure time > %g sec, aborting \n',...
                                           max(InPar.ExpTimeRange)));
                end
                
                % get Sun altitude
                Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
                if MeanValAtMax>InPar.MinFlatLimit && ...
                          MeanValAtMin<InPar.MaxFlatLimit && ...
                          (Sun.Alt*RAD)>InPar.MinSunAlt && ...
                          (Sun.Alt*RAD)<InPar.MaxSunAlt && ...
                          EstimatedExpTime>min(InPar.ExpTimeRange) &&...
                          EstimatedExpTime<max(InPar.ExpTimeRange)
                    ContFlat = true;
                else
                    ContFlat = false;
                end

                % check whether or abort commands
                % TBD
                
            end
        else
            pause(InPar.WaitTimeCheck);            
        end

        if Counter>0
            AttemptTakeFlat = false;
        end

    else
        UnitObj.report('Not ready to start flat - SunAlt is not in range\n');
        UnitObj.report(sprintf('     SunAlt             : %5.2f\n',Sun.Alt.*RAD));

        if Counter==0
            % else for (Sun.Alt.*RAD)>InPar.MinSunAlt && (Sun.Alt.*RAD)<InPar.MaxSunAlt
            pause(InPar.WaitTimeCheck);
        end
    end
end
    
% returm ImType to default value and restore SaveOnDisk
for icam=1:Ncam
    C{icam}.classCommand('ImType = ''sci'';');
    if saving(icam)
        C{icam}.classCommand('SaveOnDisk = true;');
    end
end
