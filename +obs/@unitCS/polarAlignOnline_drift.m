function [ResPolarAlign,Res]=polarAlignOnline_drift(UnitObj,itel,varargin)
% *** Might still work with mastrolindo classes
% *** First two arguments are the handles to a camera and a mount object
% *** Designed to be run in the matlab session where the objects are
%     locally defined (which is a strong limitation). Notably, the
%     showstopper is that the images to be analysed are accessed by their
%     filenames after they have supposedly been saved on disk
%
% Automatic polar alignment routine for telescopes on equatorial mount
% Package: +obs.util.tools
% Description: An automatic script for polar alignment using the drift
%              method.
%              This code measures the tracking drift of the telescope in
%              several points over the sky. Next, it attempts to fit the
%              declination drift as a function of HA/Dec in order to
%              measure the position of the mount RA axis compared to the
%              celestial pole.
%              Cfr also the offline version which works on pre-aquired
%              images, obs.util.align.polarAlignOffline_drift().
% Input  : - The index of the single camera to use for the procedure
%          * Pairs of ...,key,val,... arguments. Possible keywords are:
%            'Nimage' - Number of images per field that will be taken in
%                   order to estimate the drift in the field position.
%                   Default is 15.
%            'WaitTime' - wait time between images. Default is 10s.
%            'ExpTime' - Exposure time. Default is 5s.
%            'VecHA' - Vector of HA in which to measure drifts.
%                   Default is [-60 -30 0 30] (deg).
%            'VecDec' - Vector of Dec in which to measure drift. If scalar
%                   use the same Dec for all HA. Default is 0 (deg).
%            'Lon' - Lon (for offline mode). Default is 34.89 deg.
%            'Lat' - Lat (for offline mode). Default is 31.9 deg.
%            'Verbose' - Default is true.
%            'Verbose' - Default is true.
% Example:
%          [ResP,Res]=P.tools.polarAlignOnline_drift(1); % save -v7.3 Res.mat Res

    RAD = 180./pi;
    SEC_IN_DAY = 86400;

    InPar = inputParser;
    addOptional(InPar,'Nimage',5);   % number of images per field (fr drift)
    addOptional(InPar,'WaitTime',10);  
    addOptional(InPar,'ExpTime',5);  
    addOptional(InPar,'VecHA',[-60 0 60]);
    addOptional(InPar,'VecDec',[0]);
    addOptional(InPar,'Lon',35.04);  % for offline mode
    addOptional(InPar,'Lat',31.02);   % for offline mode
    addOptional(InPar,'Verbose',true);  
    addOptional(InPar,'Plot',true);  
    parse(InPar,varargin{:});
    InPar = InPar.Results;

    C=unitObj.Camera{itel};
    M=UnitObj.Mount;

    % set exposure time
    C.ExpTime = InPar.ExpTime;

    Lon = M.MountPos(1);
    Lat = M.MountPos(2);
    % wait time between position measurments
    Nimage   = InPar.Nimage; % number of images per field

    % select fields
    VecHA  = InPar.VecHA(:);
    VecDec = InPar.VecDec(:).*ones(numel(VecHA),1);

    Ntarget = numel(VecHA);
    clear Res;

    for Itarget=1:1:Ntarget
        %Itarget
        % for each field
        HA  = VecHA(Itarget);
        Dec = VecDec(Itarget);
        JD  = celestial.time.julday;  % current UTC JD
        LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg

        RA  = LST - HA;
        RA  = mod(RA,360);

        Res(Itarget).TargetRA  = RA;
        Res(Itarget).TargetDec = Dec;
        Res(Itarget).TargetHA  = HA;

        %--- point telescope to RA/Dec ---
        M.RA = RA;
        M.waitFinish;

        M.Dec = Dec;
        M.waitFinish;

        pause(1);

        %--- read actual telescope coordinates from mount
        Res(Itarget).MountRA  = M.RA;
        Res(Itarget).MountDec = M.Dec;
        Res(Itarget).MountHA  = M.HA;


        for Iimage=1:1:Nimage
            if InPar.Verbose
                fprintf('Target number %d -- Image number %d out of %d\n',Itarget,Iimage,Nimage);
            end

            Res(Itarget).JD(Iimage) = celestial.time.julday;

            %--- take image ---
            C.takeExposure;

            %--- wait for image ---
            C.waitFinish;
            FileName = C.LastImageName;

            %--- astrometry ---
            ResAst = obs.util.tools.astrometry_center(FileName,'RA',Res(Itarget).MountRA./RAD,...
                'Dec',Res(Itarget).MountDec./RAD);
            % save results
            Res(Itarget).S(Iimage) = ResAst.Image;
            Res(Itarget).FileName{Iimage} = FileName;
            Res(Itarget).AstR(Iimage) = ResAst.AstR;
            Res(Itarget).AstAssymRMS(Iimage) = ResAst.AstR.AssymErr;
            Res(Itarget).AstRA(Iimage)  = ResAst.CenterRA;
            Res(Itarget).AstDec(Iimage) = ResAst.CenterDec;

            if Iimage~=Nimage
                pause(InPar.WaitTime);
            end
        end

        % measure field drift
        Time = (Res(Itarget).JD-mean(Res(Itarget).JD)).*SEC_IN_DAY;

        % Drift in Declination of the field center
        %PolyPar  = polyfit(Time,Res(Itarget).AstDec.*RAD,1);  % deg/s
        [Par,ParErr,Stat]=imUtil.util.fit.linfit_sc(Time,Res(Itarget).AstDec.*RAD,1./3600);
        PolyPar = fliplr(Par(:).');
        PolyPred = polyval(PolyPar,Time);
        Resid    = Res(Itarget).AstDec.*RAD - PolyPred;
        Res(Itarget).DecDriftRMS = std(Resid.*3600)./range(Time);  % ["/s]
        Res(Itarget).DecDrift    = PolyPar(1).*3600;

        % Drift in R.A. of the field center
        %PolyPar  = polyfit(Time,Res(Itarget).AstRA.*RAD,1);
        [Par,ParErr,Stat]=imUtil.util.fit.linfit_sc(Time,Res(Itarget).AstRA.*RAD,1./3600);
        PolyPar = fliplr(Par(:).');
        PolyPred = polyval(PolyPar,Time);
        Resid    = Res(Itarget).AstRA.*RAD - PolyPred;
        Res(Itarget).RADriftRMS = std(Resid.*3600)./range(Time);  % ["/s]
        Res(Itarget).RADrift    = PolyPar(1).*3600;


        % plot
        if InPar.Plot
            clf;
            plot(Time,3600.*(Res(Itarget).AstDec.*RAD - mean(Res(Itarget).AstDec.*RAD)),'o')
            hold on
            plot(Time,3600.*(Res(Itarget).AstRA.*RAD - mean(Res(Itarget).AstRA.*RAD)),'o')
        end
        if InPar.Verbose
            fprintf('------------\n');
            fprintf('Field number: %d, image number: %d\n',Itarget,Iimage);
            fprintf('HA: %f (deg), Dec: %f (deg)\n',VecHA(Itarget),VecDec(Itarget));
            fprintf('Dec drift: %f +/- %f, RA drift: %f +/- %f\n',Res(Itarget).DecDrift,Res(Itarget).DecDriftRMS,...
                Res(Itarget).RADrift,Res(Itarget).RADriftRMS);
        end
    end