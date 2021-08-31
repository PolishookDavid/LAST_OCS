function [TargetVec,Res]=allSkyPointingOffset(C,M,varargin)
% *** Mastrolindo status: not reworked yet
% *** Might still work with mastrolindo classes
% *** First two arguments are the handles to a camera and a mount object
% *** Designed to be run in the matlab session where the objects are
%     locally defined
%

C.ExpTime = 5;


RAD = 180./pi;
clear Res;
Lon = M.MountCoo.ObsLon;

% select fields    

% Determine a pre-defined HA-Dec coordinates
Method = 2;
if (Method == 1)
%             HA Dec
TargetVec = [-60 -10
             -60   0
             -60  30
             -60  60
             -30  60
             -30  30
             -30   0
             -30 -10
               0 -10
               0   0
               0  30
               0  60
              30  60
              30  30
              30   0
              30 -10
              60 -10
              60   0
              60  30
              60  60];%+2;

Ntarget = length(TargetVec);
elseif(Method == 2)
   N_Long = 30;
   N_Lat = 15;
   [TileList,TileArea]=celestial.coo.tile_the_sky(N_Long,N_Lat);
   Inx = find((TileList(:,1)>(40)./180.*pi & TileList(:,1)<(240)./180.*pi) | TileList(:,1)>(285)./180.*pi);
   Coo = TileList(Inx,1:2);
   % Choose only coordinates with AM < 2
   AM=celestial.coo.hardie(pi./2-TileList(Inx,2));
   Inx2 = find(AM<2);
   OutCoo = celestial.coo.horiz_coo(Coo(Inx2,1:2),celestial.time.julday,[34+48/60+46/3600 31+54/60+29/3600]./180.*pi,'e');
   Ntarget = length(OutCoo);
   TargetVec = OutCoo.*180./pi;
end

for Itarget=1:1:Ntarget
%for Itarget=5:1:6
   if (Method == 1)
       fprintf('target %d: HA=%d, Dec=%d\n', Itarget, TargetVec(Itarget,1), TargetVec(Itarget,2))

       % for each field

       HA  = TargetVec(Itarget,1);
       Dec = TargetVec(Itarget,2);
       JD  = celestial.time.julday;  % current UTC JD
       LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg

       RA  = LST - HA;
       RA  = mod(RA,360);

       Res(Itarget).TargetRA  = RA;
       Res(Itarget).TargetDec = Dec;
       Res(Itarget).TargetHA  = HA;
   elseif(Method == 2)

       % for each field

       RA = TargetVec(Itarget,1);
       Dec = TargetVec(Itarget,2);
       JD  = celestial.time.julday;  % current UTC JD
       LST = celestial.time.lst(JD,Lon./RAD,'a').*360;  % deg

       HA  = LST - RA;

       Res(Itarget).TargetRA  = RA;
       Res(Itarget).TargetDec = Dec;
       Res(Itarget).TargetHA  = HA;

       fprintf('target %d: RA=%.2f, Dec=%.2f\n', Itarget, TargetVec(Itarget,1), TargetVec(Itarget,2))

   end

   
   
   %--- point telescope to RA/Dec ---   
   M.RA = RA;
   M.waitFinish;

   M.Dec = Dec;
   M.waitFinish;

   %--- read actual telescope coordinates from mount   
   Res(Itarget).MountRA  = M.RA;
   Res(Itarget).MountDec = M.Dec;
   Res(Itarget).MountHA  = M.HA;
   Res(Itarget).JD = celestial.time.julday;
   
   %--- take image ---
   C.takeExposure; C.waitFinish;
   FileName = C.LastImageName;
   
   %--- astrometry ---

   try
      ResAst = obs.util.tools.astrometry_center(FileName,'RA',Res(Itarget).MountRA./RAD,...
                                                'Dec',Res(Itarget).MountDec./RAD);
                                            
      % save results
      Res(Itarget).S = ResAst.Image;
      Res(Itarget).FileName = FileName;
      Res(Itarget).AstR = ResAst.AstR;
      Res(Itarget).AstAssymRMS = ResAst.AstR.AssymErr;
      Res(Itarget).AstRA  = ResAst.CenterRA.*RAD;
      Res(Itarget).AstDec = ResAst.CenterDec.*RAD;   
   catch
      % save NaN if failed 
      Res(Itarget).S = NaN;
      Res(Itarget).FileName = FileName;
      Res(Itarget).AstR = NaN;
      Res(Itarget).AstAssymRMS = NaN;
      Res(Itarget).AstRA  = NaN;
      Res(Itarget).AstDec = NaN;   
   end

end


%%

if 1==0
    RAD = 180./pi;
    Lon = 34.9;

    N = numel(Res);
    Table = nan(N,6);
    for I=1:1:N
        Table(I,:) = [Res(I).JD, Res(I).AstRA, Res(I).AstDec, Res(I).AstRA-Res(I).TargetRA, Res(I).AstDec-Res(I).TargetDec, Res(I).AstAssymRMS.*3600];
    end
    Table = Table(~isnan(Table(:,6)),:);
    LST   = celestial.time.lst(Table(:,1),Lon./RAD,'a').*360;
    HA    = LST - Table(:,2);
    Table(:,2) = HA;
    scatter(Table(:,2),Table(:,3),150,Table(:,5),'filled')
    colorbar
    box on

    II = 6;
    F_RA  = scatteredInterpolant(Table(:,2),Table(:,3),Table(:,4),'linear','linear');
    F_Dec = scatteredInterpolant(Table(:,2),Table(:,3),Table(:,5),'linear','linear');

    LST   = celestial.time.lst(Res3(II).JD,Lon./RAD,'a').*360;
    HA    = LST - Res3(II).AstRA;

    InterpDiffRA  = F_RA(HA,Res3(II).AstDec);
    InterpDiffDec = F_Dec(HA,Res3(II).AstDec);

    ObsDiffRA  = Res3(II).AstRA - Res3(II).TargetRA;
    ObsDiffDec = Res3(II).AstDec - Res3(II).TargetDec;


    (ObsDiffRA - InterpDiffRA).*3600.*cosd(Res3(II).AstDec)
    (ObsDiffDec - InterpDiffDec).*3600
end
