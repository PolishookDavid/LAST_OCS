function auto_polar_align(CamObj,MountObj)
% Automatic polar alignment routine for telescopes on equatorial mount
% Example: devel.auto_polar_align(C,M)

M = MountObj; % mount object;
C = CamObj; % camera object;
    

RAD = 180./pi;
SEC_IN_DAY = 86400;

Lon = 35;
Lat = 32;
WaitTime = 60;   % wait time between position measurments
Nimage   = 5;    % number of images per field
Plot     = true;

%
% select fields
VecHA  = [-60:30:60].';
VecDec = 0.*ones(size(VecHA));

Ntarget = numel(VecHA);
for Itarget=1:1:Ntarget
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
%    wait
    M.Dec = Dec;
%    wait
    
    %--- read actual telescope coordinates from mount
    Res(Itarget).MountRA  = M.RA;
    Res(Itarget).MountDec = M.Dec;
    Res(Itarget).MountHA  = M.HA;
    
    
    for Iimage=1:1:Nimage
        Res(Itarget).JD(Iimage) = celestial.time.julday;
        
        %--- take image ---
        C.takeExposure;

        %--- wait for image ---
        ReadoutTime = 10; % seconds
        % calculate wait
        pause(C.ExpTime + ReadoutTime)
        FileName = C.LastImageName;

        %--- load image ---
        S = FITS.read2sim(FileName);

        %--- trim image around center ---
        % REPLACE WITH REAL READOUT FROM HEADER:
        Xcenter = 6388/2;
        Ycenter = 9600/2;
        
        HalfSize = 1000;
        CCDSEC = [Xcenter, Xcenter, Ycenter, Ycenter] + [-HalfSize HalfSize -HalfSize HalfSize];
        S = trim_image(S,CCDSEC);

        %--- solve astrometry ---
        A
        [AstR,S] = astrometry(S,'RA',RA,...
                                'Dec',Dec,...
                                'Scale',1.25,...
                                'Niter',1,...
                                'Flip',[1 1],...
                                'RefCatMagRange',[8 16],...
                                'RCrad',1.5./RAD,...
                                'BlockSize',[3000 3000],...
                                'SearchRangeX',[-4000 4000],...
                                'SearchRangeY',[-4000 4000]);

        
        Res(Itarget).AstAssymRMS(Iimage) = AstR.AssymErr;
        Res(Itahet).AstNsrc(Iimage)      = AstR.NsrcN;

        %--- calc center of field of view ---
        [Res(Itarget).AstRA(Iimage),Res(Itarget).AstDec(Iimage)] = xy2coo(S,Xcenter,Ycenter);

        if I~=Nimage
            pause(WaitTime);
        end
    end
    
    % measure field drift
    Time = Res(Itarget).JD-mean(Res(Itarget).JD).*SEC_IN_DAY;
    % Drift in Declination
    PolyPar  = polyfit(Time,Res(Itarget).AstDec,1);
    PolyPred = polyval(PolyPar,Time);
    Resid    = Res(Itarget).AstDec - PolyPred;
    Res(Itarget).DecDriftRMS = std(Resid);  % ["/s]
    Res(Itarget).DecDrift    = PolyPar(2);
    
    % Drift in R.A.
    PolyPar  = polyfit(Time,Res(Itarget).AstRA,1);
    PolyPred = polyval(PolyPar,Time);
    Resid    = Res(Itarget).AstRA - PolyPred;
    Res(Itarget).RADriftRMS = std(Resid);  % ["/s]
    Res(Itarget).RADrift    = PolyPar(2);
    
end


[ResPolarAlign] = celestial.coo.polar_alignment([Res.MountHA],[Res.MountDec],[Res.DecDrift],(90-Lat)./RAD,Plot);

