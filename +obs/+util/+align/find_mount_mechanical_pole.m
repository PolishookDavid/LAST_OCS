function find_mount_mechanical_pole(C,X,varargin)
% *** Mastrolindo status: not reworked yet
% *** Might still work with (local) mastrolindo classes
% *** First two arguments are the handles to a camera and a mount object
% *** Designed to be run in the matlab session where the objects are
%     locally defined

RAD = 180./pi;
SEC_IN_DAY = 86400;

InPar = inputParser;
addOptional(InPar,'VecPoleDec',91.5); %[91:0.5:92.5]);
addOptional(InPar,'VecHA',[-30:30:30]);


addOptional(InPar,'PoleDec',+89.9999);
addOptional(InPar,'PolarisRA',celestial.coo.convertdms([12+2 31 49.09],'H','d'));  % deg  J2000
addOptional(InPar,'PolarisDec',celestial.coo.convertdms([1 89 15 50.8],'D','d'));  % deg  J2000
addOptional(InPar,'PixScale',1.251);  % "/pix
addOptional(InPar,'Xalong','-ra');   % 'ra','-ra','dec','-dec'
addOptional(InPar,'Yalong','dec');  % 'ra','-ra','dec','-dec'

addOptional(InPar,'ExpTime',10);
addOptional(InPar,'Verbose',true);  
addOptional(InPar,'Plot',true);  
addOptional(InPar,'MarkerPolaris','ro'); 
addOptional(InPar,'MarkerCelPole','bo'); 
addOptional(InPar,'MarkerMountPole','co'); 
addOptional(InPar,'MarkerSize',50); 
addOptional(InPar,'HalfSize',[]); 


parse(InPar,varargin{:});
InPar = InPar.Results;


C.ExpTime = InPar.ExpTime;

Ndec = numel(InPar.VecPoleDec);
Nha  = numel(InPar.VecHA);


for Idec=1:1:Ndec
    X.Dec = InPar.VecPoleDec(Idec);
    
    for Iha=1:1:Nha
        X.HA = InPar.VecHA(Iha);
        
        C.takeExposure
        C.waitFinish
        
        Image = single(C.LastImage);
        FN    = C.LastImageName;
        Res = obs.util.tools.astrometry_center(FN,'RA',0,'Dec',pi./2);
        
        [Res(Idec).Res(Iha).PolarisX, Res(Idec).Res(Iha).PolarisY]=ds9.coo2xy(InPar.PolarisRA, InPar.PolarisDec);
        [Res(Idec).Res(Iha).CelPoleX, Res(Idec).Res(Iha).CelPoleY]=ds9.coo2xy(0, 90.*sign(InPar.PoleDec));
        
    end
    X = [Res(Idec).Res.PolarisX];
    Y = [Res(Idec).Res.PolarisY];
    CircData = [X(:), Y(:)];
    [BestCen,BestRad,BestRMS]   = imUtil.util.fit.circ_fit(CircData,'plane');
    Res(Idec).BestPolarisCen    = BestCen;
    Res(Idec).BestPolarisRadius = BestRad;
    Res(Idec).BestPolarisRMS    = BestRMS;
    
    if InPar.Plot
        ds9.plot(BestCen(1),BestCen(2),InPar.MarkerMountPole,'Size',InPar.MarkerSize.*[1 1 0]);
        % mark polaris pointings over all images
        ds9.plot(X(:),Y(:),InPar.MarkerPolaris,'Size',InPar.MarkerSize.*[1 1 0]);
        % mark celestial pole on the HA=0 image
        Iha0 = find(VecHA==0);
        ds9.plot(Res(Idec).Res(Iha0).CelPoleX, Res(Idec).Res(Iha0).CelPoleY, InPar.MarkerCelPole,'Size',InPar.MarkerSize.*[1 1 0]);
    end
end

        