function takeDarks(C, Args)
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
%   - 'PrepMasterDark' - A logical indicating if to generate a master dark.
%                        Default is true.
%   - 'SaveDir'        - Where to save the master dark. Default is pwd.
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


arguments
    C
    Args.ExpTime         = 20;
    Args.Ndark           = 10;
    Args.Temp            = [];  % -5;  empty - do not change
    Args.MaxTempDiff     = 2;
    Args.WaitTempTimeout = 180;
    Args.ImType          = 'dark';
    
    Args.PrepMasterDark logical = true;
    Args.SaveDir                = pwd;
end



SavingState  = C.SaveOnDisk;
C.SaveOnDisk = true;

if isempty(Args.Temp)
    % use current Temperature
    Args.Temp = C.Temperature;
end

Nexp  = numel(Args.ExpTime);
Ntemp = numel(Args.Temp);

ImageNames = struct('List',cell(Ntemp, Nexp));
for Itemp=1:Ntemp
    targetTemp = Args.Temp(Itemp);
    C.Temperature = targetTemp;
    % wait for temperature to stablize
    t0=now;
    while (now-t0)*86400 < Args.WaitTempTimeout
        pause(10)
        CoolingPower      = C.CoolingPower;
        cameraTemperature = C.Temperature;
        C.report('   Requested Temperature : %.1f°C, Actual : %.1f°C\n',...
                         targetTemp,cameraTemperature);
        if abs(cameraTemperature-targetTemp)<Args.MaxTempDiff
            break
        end
    end
    
    if abs(cameraTemperature-targetTemp)<Args.MaxTempDiff
        % && CoolingPower<100 % Are we concerned, if cooling power is max?
        % ok to continue
        
        C.ImType = Args.ImType;
        
        for Iexp=1:Nexp
            ExpTime=Args.ExpTime(Iexp);
            C.ExpTime = ExpTime;
            C.report('Taking %d dark exposure(s) of %g sec at T=%.1f°C\n',...
                             Args.Ndark,ExpTime,C.Temperature);
%             if false && Args.Ndark>1 && ExpTime>5 %% FIXME when we can save 
%                 C.takeLive(Args.Ndark);
%                 % saving is missing here yet
%                 C.waitFinish
%             else
                
            ImageNames(Itemp,Iexp).List = cell(1, Args.Ndark);
            for Idark=1:Args.Ndark
                C.takeExposure;
                C.waitFinish;
                %C.saveCurImage(C.Config.DarkDBDir)
                ImageNames(Itemp,Iexp).List{Idark} = C.LastImageName;
            end
%             end
        end
        
        % prepare Master Dark image
        if Args.PrepMasterDark
            CI = CalibImages;
            CI.createBias(ImageNames(Itemp, Iexp).List);
            
            % Save Master Dark image
            IP = ImagePath;
            IP.ProjName = C.ProjName;
            IP.Counter  = 0;
            IP.CCDID    = 1;
            IP.CropID   = 0;
            IP.Type     = Args.ImType;
            IP.Level    = 'proc';
            IP.Product  = 'Image';
            IP.FileType = 'fits';
            
            MasterBiasName = sprintf('%s%s%s',Args.SaveDir, filesep, IP.genFile);
            write1(CI.Bias, MasterBiasName, IP.Product, 'FileType',IP.FileType);
            IP.Product  = 'Mask';
            MasterBiasName = sprintf('%s%s%s',Args.SaveDir, filesep, IP.genFile);
            write1(CI.Bias, MasterBiasName, IP.Product, 'FileType',IP.FileType);
            IP.Product  = 'Var';
            MasterBiasName = sprintf('%s%s%s',Args.SaveDir, filesep, IP.genFile);
            write1(CI.Bias, MasterBiasName, IP.Product, 'FileType',IP.FileType);
            
        end
    else
        C.reportError('Temperature did not reach the target of %.1f°C',...
                               targetTemp);
    end
end

% restore default values
C.ImType = 'science';
C.SaveOnDisk = SavingState;


