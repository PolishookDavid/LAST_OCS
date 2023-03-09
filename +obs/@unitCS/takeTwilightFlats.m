function takeTwilightFlats(UnitObj, Itel, Args)
% *** Mastrolindo status: works, but needs serious redesign, see below.
%
% Obtain a series of twiligh flat images using a LAST pier system.
% Package: +obs.unitCS
% Description: Obtain a series of Twiligh flat images automatically. The
%              exposure time is selected based on sky brightness.
% Input  : - indices of cameras to operate ([]=all)
%          - optional key - values:
%               'MaxFlatLimit'   [40000]
%               'MinFlatLimit'   [6000]
%               'MinSunAlt'      [-10]
%               'MaxSunAlt'      [-4]
%               'ExpTimeRange    [3 15]
%               'TestExpTime'    [1]
%               'MeanFun'        [nanmedian] ** use string, not handle,
%                                            ** eval() in slave
%               'EastFromZenith' [20]
%               'RandomShift'    [3]
%               'ImType'         ['skyflat']
%               'WaitTimeCheck'  [30]
%               'Plot'           true
%               'LiveMode'       false
%
% Output : - none, but flat images are saved on disk, TODO in the directories
%  specified by each camera's Config.FlatDBDir
%     By :
% Example: P.take_twilight_flat();
%
% Notes: I made it sort of work with mastrolindo, but code should be
%  revised:
%  - most of the code is duplicated; that should be factored;
%  - for many cameras, estimated exposure times should be individual and
%    not the mean of all of them;
%  - a real stopping mechanism should be in place, including a max number
%    of flat images to take

arguments
    UnitObj
    Itel       = [];
    Args.MaxFlatLimit         = 40000;
    Args.MinFlatLimit         = 6000;
    Args.MinSunAlt            = -8;
    Args.MaxSunAlt            = -4;  % for DEBUG use 90
    Args.ExpTimeRange         = [3 20];
    Args.TestExpTime          = 1;
    Args.MeanFun              = 'nanmedian';
    Args.EastFromZenith       = 30;
    Args.RandomShift          = 3;
    
    Args.ImType               = 'twflat';
    Args.WaitTimeCheck        = 30;
    Args.Plot logical         = true;
    Args.LiveMode             = false;
    
    Args.PrepMasterFlat logical = false;
    
    Args.AbortFile            = '~/stopFF';
    
end

if isempty(Itel)
    Itel = (1:numel(UnitObj.Camera));
end

Ncam = numel(Itel);

    
RAD = 180./pi;

M = UnitObj.Mount;
C = UnitObj.Camera(Itel);

% store the present status of SaveOnDisk for each camera. We will save
%  images, but use an explicit call in order to provide the path, with
%  SaveOnDisk=false
for icam=1:Ncam
    % set ImType to flat
    UnitObj.Camera{icam}.classCommand(['ImType =''' Args.ImType ''';']);
end

Lon = M.classCommand('MountPos(2)');
Lat = M.classCommand('MountPos(1)');

% get Sun Altitude

Counter = 0;
I = 0;
AttemptTakeFlat = true;
ListOfFlatFiles = struct('List',cell(1,Ncam));
while AttemptTakeFlat
    I = I + 1;
    
    Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);

    if exist(Args.AbortFile,'file') 
        delete(Args.AbortFile);
        break
    end
        
    if (Sun.Alt*RAD)>Args.MinSunAlt && (Sun.Alt*RAD)<Args.MaxSunAlt
        % get sky position for flat fielding
        pause(3);
        [RA, Dec] = getCooForFlat(Lon, Lat, Args.EastFromZenith);
        
        % set telescope coordinates
        UnitObj.Mount.goToTarget(RA,Dec);
        
        % estimate mean count rate in images
        getMeanCountPerSec(UnitObj, Itel, Args.TestExpTime, Args.MeanFun, Args.LiveMode)
        MeanValPerSec = getMeanCountPerSec(UnitObj, Itel, Args.TestExpTime, Args.MeanFun, Args.LiveMode);
        
        % DEBUG
        %MeanValPerSec = 670  
        
        MeanValAtMin = mean(MeanValPerSec) * min(Args.ExpTimeRange);
        MeanValAtMax = mean(MeanValPerSec) * max(Args.ExpTimeRange);
        
        if MeanValAtMax>Args.MinFlatLimit && MeanValAtMin<Args.MaxFlatLimit
            % Sun Altitude and image mean value are in allowed range
            % start twilight flat sequemce
            
            ContFlat = true;
            while ContFlat
                % take flat images
                Counter = Counter + 1;
        
                if exist(Args.AbortFile,'file') 
                    break
                end
                
                RA  = RA  + (rand(1,1)-0.5).*2.*Args.RandomShift;
                Dec = Dec + (rand(1,1)-0.5).*2.*Args.RandomShift;
                UnitObj.Mount.goToTarget(RA,Dec);         
                UnitObj.Mount.waitFinish;
                
                
                % estimated xp time
                EstimatedExpTime = min(Args.MaxFlatLimit/mean(MeanValPerSec), max(Args.ExpTimeRange));

                % take images
                UnitObj.takeExposure(Itel, EstimatedExpTime, 1, ...
                             'ImType','twflat','LiveSingleImage',Args.LiveMode);
                UnitObj.readyToExpose('Itel',Itel, 'Wait',true, 'Timeout',EstimatedExpTime+20);
                
                for Icam=1:1:Ncam
                    ListOfFlatFiles(Icam).List{Counter} = UnitObj.Camera{Icam}.classCommand('LastImageName');
                end
                        
                MeanValPerSec = getMeanVal(UnitObj, Itel, Args.MeanFun, EstimatedExpTime);
                MeanValAtMin = mean(MeanValPerSec) * min(Args.ExpTimeRange);
                MeanValAtMax = mean(MeanValPerSec) * max(Args.ExpTimeRange);
                
                UnitObj.report('Flat test image\n');
                UnitObj.report('    SunAlt              : %6.2f\n',Sun.Alt.*RAD)
                UnitObj.report('    Az                  : %6.2f\n',M.classCommand('Az'))
                UnitObj.report('    Alt                 : %6.2f\n',M.classCommand('Alt'))
                UnitObj.report('    Image ExpTime       : %6.2f\n',EstimatedExpTime)
                UnitObj.report('    Image MeanValPerSec : %5.1f\n',mean(MeanValPerSec))
               
                Sun = celestial.SolarSys.get_sun(celestial.time.julday,[Lon Lat]./RAD);
                if MeanValAtMax>Args.MinFlatLimit && MeanValAtMin<Args.MaxFlatLimit && ...
                                    (Sun.Alt*RAD)>Args.MinSunAlt && (Sun.Alt*RAD)<Args.MaxSunAlt
                    ContFlat = true;
                else
                    ContFlat         = false;
                    AttemptTakeFlat  = false;
                end
            end
        else
            UnitObj.report('Estimated exposure time < %g sec, waiting \n',...
                               min(Args.ExpTimeRange));
        end
    else
        UnitObj.report('Not ready to start flat - SunAlt is not in range\n');
        UnitObj.report('     SunAlt             : %5.2f\n',Sun.Alt.*RAD)

        if Counter==0
            % else for (Sun.Alt.*RAD)>Args.MinSunAlt && (Sun.Alt.*RAD)<Args.MaxSunAlt
            pause(Args.WaitTimeCheck);
        end
    end
end
             
% returm ImType to default value and restore SaveOnDisk
for icam=1:Ncam
    C{icam}.classCommand('ImType = ''sci'';');
end

% prep a master flat image
if Args.PrepMasterFlat
    CI = CalibImages;
    
    for Icam=1:1:Ncam
        % upload the Master dark image
        % get the bias dir name 
        Config = UnitObj.Camera{Icam}.classCommand('Config');
        DirDark = Config.CalibDarkDir;
        SaveDir = Config.CalibFlatDir;
        
        [FoundAll,MostRecentFile,MostRecentRep] = searchNewFilesInDir(DirDark, '*_dark_proc_*Image_*', '_Image_', {'_Mask_'});
        
        MasterDarkImageFileName = sprintf('%s%s%s',DirDark, filesep, MostRecentFile);
        MasterDarkMaskFileName  = sprintf('%s%s%s',DirDark, filesep, MostRecentRep);
        
        Dark   = AstroImage(MasterDarkImageFileName, 'Mask', MasterDarkMaskFileName);
        CI.Bias = Dark;
        
        FlatImages = CI.debias(ListOfFlatFiles(Icam).List);
        CI.createFlat(FlatImages);
        
        IP = ImagePath;
        IP.ProjName = Config.ProjName;
        IP.Counter  = 0;
        IP.CCDID    = 1;
        IP.CropID   = 0;
        IP.Type     = Args.ImType;
        IP.Level    = 'proc';
        IP.Product  = 'Image';
        IP.FileType = 'fits';
        
        MasterFlatName = sprintf('%s%s%s',SaveDir, filesep, IP.genFile);
        write1(CI.Flat, MasterFlatName, IP.Product, 'FileType',IP.FileType);
        IP.Product  = 'Mask';
        MasterFlatName = sprintf('%s%s%s',SaveDir, filesep, IP.genFile);
        write1(CI.Flat, MasterFlatName, IP.Product, 'FileType',IP.FileType);
        IP.Product  = 'Var';
        MasterFlatName = sprintf('%s%s%s',SaveDir, filesep, IP.genFile);
        write1(CI.Flat, MasterFlatName, IP.Product, 'FileType',IP.FileType);
        
    end
end


end


function MeanValPerSec = getMeanCountPerSec(UnitObj, Itel, TestExpTime, MeanFun, LiveMode)
    % Take exposures with all cameras 
    % do not save images
    % calculate the median counts per second
   
    Ncam = numel(Itel);

    % save off
    SavingState = false(1,Ncam);
    for icam=1:Ncam
        SavingState(icam) = UnitObj.Camera{icam}.classCommand('SaveOnDisk;');
        UnitObj.Camera{icam}.classCommand('SaveOnDisk = false;');
    end
    
    UnitObj.takeExposure(Itel, TestExpTime, 1, 'LiveSingleImage',LiveMode);
    
    UnitObj.readyToExpose('Itel',Itel, 'Wait',true);
                    
    MeanValPerSec = getMeanVal(UnitObj,  Ncam, MeanFun, TestExpTime);
    
    % save on
    for icam=1:Ncam
        if SavingState(icam)
            UnitObj.Camera{icam}.classCommand('SaveOnDisk = true;');
        end
    end
    
end


function MeanValPerSec = getMeanVal(UnitObj, Ncam, MeanFun, ExpTime)
    % get LastImages mean value per second
    
    
    for icam=1:Ncam
        % compute mean of the image taken (remotely if the camera is remote)
        
        ImageMean = UnitObj.Camera{icam}.Messenger.query(sprintf('%s(single(%s.LastImage(:)))',...
                                             MeanFun,UnitObj.Camera{icam}.RemoteName));
        MeanValPerSec(icam) = ImageMean/ExpTime;
    end
     
end

function [RA, Dec] = getCooForFlat(Lon, Lat, EastFromZenith)
    % get RA/Dec for good flat
    % some deg east of the Zenith and avoid galactic plane
    % and avoid Moon

    MinMoonDist = 20;  % deg
    RAD = 180./pi;
    
    JD  = celestial.time.julday;  % current UTC JD
    
    [MoonRA,MoonDec] = celestial.SolarSys.mooncool(JD,[]);
    
    
    LST = celestial.time.lst(JD, Lon./RAD,'a').*360;  % deg
    RA  = LST - 0;  % RA at HA=0
    RA  = RA + EastFromZenith + [-20:5:20].';
    RA  = mod(RA,360);    
    Dec = Lat + zeros(size(RA));
    
    % remove pointings close to the Moon
    MoonDist = celestial.coo.sphere_dist_fast(MoonRA, MoonDec, RA./RAD, Dec./RAD).*RAD;  % [deg]
    Flag = MoonDist>MinMoonDist;
    RA   = RA(Flag);
    Dec  = Dec(Flag);
    
    % check Galactic Lat
    [Lon,Lat] = celestial.coo.convert_coo(RA./RAD, Dec./RAD, 'J2000.0','g');
    [~,Ira] = max(abs(Lat));
    RA  = RA(Ira);
    Dec = Dec(Ira);
    
end
