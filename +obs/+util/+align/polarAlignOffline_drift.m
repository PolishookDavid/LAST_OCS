function [ResPolarAlign,Res]=polarAlignOffline_drift(Files,varargin)
% Automatic polar alignment routine for telescopes on equatorial mount
% Package: +obs.util.align
% Description: An automatic script for polar alignment using the drift
%              method.
%              This code measures the tracking drift of the telescope in
%              several points over the sky. Next, it attempts to fit the
%              declination drift as a function of HA/Dec in order to
%              measure the position of the mount RA axis compared to the
%              celestial pole.
%              The script can also works offline on pre-aquired images.
% Input  : - Image files to analyze
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
%          [ResP,Res]=obs.util.polarAlignOffline_drift(List)   % offline mode
%
% cfr. also obs.unitCS.polarAlignOnline_drift(), the online version of the
%  same procedure

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



if iscell(Files)
    %--- OFFLINE MODE ---
    % camera object is a cell array of file names
    
    Lon = InPar.Lon;
    Lat = InPar.Lat;
        
    N = numel(Files);
    S = FITS.read2sim(Files);
    VecRA  = cell2mat(getkey(S,'RA'));
    VecDec = cell2mat(getkey(S,'DEC'));
    VecHA = cell2mat(getkey(S,'HA'));
    VecJD = cell2mat(getkey(S,'JD'));
    
    Ntarget = 4;
    Nimage  = 3;
    
    K = 0;
    for Itarget=1:1:Ntarget
        for Iimage=1:1:Nimage
            K = K + 1;
            
            Res(Itarget).MountHA = VecHA(K);
            Res(Itarget).MountDec = VecDec(K);
            Res(Itarget).JD(Iimage) = VecJD(K);
            
            %--- astrometry ---
            ResAst = obs.util.tools.astrometry_center(S(K));
            % save results
            Res(Itarget).S(Iimage) = ResAst.Image;
            Res(Itarget).FileName{Iimage} = Files{K};
            Res(Itarget).AstR(Iimage) = ResAst.AstRes;
            Res(Itarget).AstAssymRMS(Iimage) = ResAst.AstRes.AssymErr;
            Res(Itarget).AstRA(Iimage)  = ResAst.CenterRA;
            Res(Itarget).AstDec(Iimage) = ResAst.CenterDec;

        end
        
        % measure field drift
        Time = (Res(Itarget).JD-mean(Res(Itarget).JD)).*SEC_IN_DAY;

        % Drift in Declination
        PolyPar  = polyfit(Time,Res(Itarget).AstDec.*RAD,1);  % deg/s
        PolyPred = polyval(PolyPar,Time);
        Resid    = Res(Itarget).AstDec.*RAD - PolyPred;
        Res(Itarget).DecDriftRMS = std(Resid.*3600)./range(Time);  % ["/s]
        Res(Itarget).DecDrift    = PolyPar(1).*3600;

        % Drift in R.A.
        PolyPar  = polyfit(Time,Res(Itarget).AstRA.*RAD,1);
        PolyPred = polyval(PolyPar,Time);
        Resid    = Res(Itarget).AstRA.*RAD - PolyPred;
        Res(Itarget).RADriftRMS = std(Resid.*3600)./range(Time);  % ["/s]
        Res(Itarget).RADrift    = PolyPar(1).*3600;
        
    end
    
end

%%


%%
ResPolarAlign = [];
clf;
[ResPolarAlign] = celestial.coo.polar_alignment([Res.MountHA]./RAD,[Res.MountDec]./RAD,[Res.DecDrift],[Res.RADrift],Lat./RAD,InPar.Plot);
