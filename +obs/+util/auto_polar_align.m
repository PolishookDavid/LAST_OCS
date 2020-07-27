function [ResPolarAlign,Res]=auto_polar_align(CamObj,MountObj,varargin)
% Automatic polar alignment routine for telescopes on equatorial mount
% Example: obs.util.auto_polar_align(C,M)
%          [ResP,Res]=obs.util.auto_polar_align(List)
%          [~,Res]=obs.util.auto_polar_align(C,M); % save -v7.3 Res.mat Res

RAD = 180./pi;
SEC_IN_DAY = 86400;

InPar = inputParser;
addOptional(InPar,'WaitTime',10);  % If empty, use the entire image
addOptional(InPar,'Plot',true);  % If empty, use the entire image

parse(InPar,varargin{:});
InPar = InPar.Results;



if iscell(CamObj)
    % camera object is a cell array of file names
    % offline mode
    
    Lon = 34.85;
    Lat = 31.9;
    
    FileName = CamObj;
    
    N = numel(FileName);
    S = FITS.read2sim(FileName);
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
            ResAst = obs.util.astrometry_center(S(K));
            % save results
            Res(Itarget).S(Iimage) = ResAst.Image;
            Res(Itarget).FileName{Iimage} = FileName{K};
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
    



    
    
else
    % assume camera and mount object are provided
    
    M = MountObj; % mount object;
    C = CamObj; % camera object;

    %%
    
    Lon = M.MountPos(1);
    Lat = M.MountPos(2);
    % wait time between position measurments
    Nimage   = 12;    % number of images per field
    

    %
    % select fields
    VecHA  = [-50,-20,+10]; %:25:15].';
    VecDec = 0.*ones(size(VecHA));

    Ntarget = numel(VecHA);
    clear Res;

    for Itarget=1:1:Ntarget
        Itarget
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
            Iimage
            Res(Itarget).JD(Iimage) = celestial.time.julday;

            %--- take image ---
            C.takeExposure;

            %--- wait for image ---
            C.waitFinish;
            FileName = C.LastImageName;

            %--- astrometry ---
            ResAst = obs.util.astrometry_center(FileName,'RA',Res(Itarget).MountRA./RAD,...
                                                         'Dec',Res(Itarget).MountDec./RAD);
            % save results
            Res(Itarget).S(Iimage) = ResAst.Image;
            Res(Itarget).FileName{Iimage} = FileName;
            Res(Itarget).AstR(Iimage) = ResAst.AstR;
            Res(Itarget).AstAssymRMS(Iimage) = ResAst.AstR.AssymErr;
            Res(Itarget).AstRA(Iimage)  = ResAst.CenterRA;
            Res(Itarget).AstDec(Iimage) = ResAst.CenterDec;





    %         S = FITS.read2sim(FileName);
    % 
    %         %--- trim image around center ---
    %         % REPLACE WITH REAL READOUT FROM HEADER:
    %         Xcenter = 6388/2;
    %         Ycenter = 9600/2;
    %         
    %         HalfSize = 1000;
    %         CCDSEC = [Xcenter, Xcenter, Ycenter, Ycenter] + [-HalfSize HalfSize -HalfSize HalfSize];
    %         S = trim_image(S,CCDSEC);
    % 
    %         %--- solve astrometry ---
    %         %
    %         S = mextractor(S);
    %         
    %         [AstR,S] = astrometry(S,'RA',RA./RAD,...
    %                                 'Dec',Dec./RAD,...
    %                                 'Scale',1.25,...
    %                                 'Flip',[1 1],...
    %                                 'RefCatMagRange',[9 16],...
    %                                 'RCrad',1.5./RAD,...
    %                                 'BlockSize',[3000 3000],...
    %                                 'SearchRangeX',[-4000 4000],...
    %                                 'SearchRangeY',[-4000 4000]);
    % 
    %         Res(Itarget).S(Iimage) = S;
    %         Res(Itarget).FileName{Iimage} = FileName;
    %         Res(Itarget).AstR(Iimage) = AstR;
    %         Res(Itarget).AstAssymRMS(Iimage) = AstR.AssymErr;
    %         Res(Itarget).AstNsrc(Iimage)      = AstR.NsrcN;
    % 
    %         %--- calc center of field of view ---ope
    %         W = ClassWCS.populate(S);
    %         [Res(Itarget).AstRA(Iimage),Res(Itarget).AstDec(Iimage)] = xy2coo(W,[HalfSize,HalfSize]);
    %         Res(Itarget).AstRA(Iimage)  = Res(Itarget).AstRA(Iimage).*RAD;
    %         Res(Itarget).AstDec(Iimage) = Res(Itarget).AstDec(Iimage).*RAD;

            if Iimage~=Nimage
                pause(InPar.WaitTime);
            end
        end

        % measure field drift
        Time = (Res(Itarget).JD-mean(Res(Itarget).JD)).*SEC_IN_DAY;

        % Drift in Declination of the field center
        PolyPar  = polyfit(Time,Res(Itarget).AstDec.*RAD,1);  % deg/s
        PolyPred = polyval(PolyPar,Time);
        Resid    = Res(Itarget).AstDec.*RAD - PolyPred;
        Res(Itarget).DecDriftRMS = std(Resid.*3600)./range(Time);  % ["/s]
        Res(Itarget).DecDrift    = PolyPar(1).*3600;

        % Drift in R.A. of the field center
        PolyPar  = polyfit(Time,Res(Itarget).AstRA.*RAD,1);
        PolyPred = polyval(PolyPar,Time);
        Resid    = Res(Itarget).AstRA.*RAD - PolyPred;
        Res(Itarget).RADriftRMS = std(Resid.*3600)./range(Time);  % ["/s]
        Res(Itarget).RADrift    = PolyPar(1).*3600;

        
        % plot
        clf;
        plot(Time,3600.*(Res(Itarget).AstDec.*RAD - mean(Res(Itarget).AstDec.*RAD)),'o')
        hold on
        plot(Time,3600.*(Res(Itarget).AstRA.*RAD - mean(Res(Itarget).AstRA.*RAD)),'o')
    end
end

%%



%%
ResPolarAlign = [];
clf;
[ResPolarAlign] = celestial.coo.polar_alignment([Res.MountHA]./RAD,[Res.MountDec]./RAD,[Res.DecDrift],[Res.RADrift],Lat./RAD,InPar.Plot);
