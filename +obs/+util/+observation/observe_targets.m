function observe_targets(C,M,varargin)
% *** Mastrolindo status: not reworked yet
% *** Might still work with mastrolindo classes
% *** First two arguments are the handles to a camera and a mount object
% *** Designed to be run in the matlab session where the objects are
%     locally defined
%
% Example: obs.util.tools.observe_targets(M,C);


RAD = 180./pi;


InPar = inputParser;
addOptional(InPar,'List',[]);
addOptional(InPar,'ExpTime',15);
addOptional(InPar,'Nexp',20);
addOptional(InPar,'Lon',[]);
addOptional(InPar,'Lat',[]);
addOptional(InPar,'AbortFile','/home/eran/abort');
addOptional(InPar,'Verbose',true);
parse(InPar,varargin{:});
InPar = InPar.Results;

if isempty(InPar.Lon) || isempty(InPar.Lat)
    MountPos = M.MountPos;
    InPar.Lon = MountPos(1);
    InPar.Lat = MountPos(2);
    
end


if isempty(InPar.List)

    InPar.List = {'16:41:41.24','+36:27:35.5','M13';...
            '16:57:8.92','-04:05:58.07','M10';...
            '17:22:38.2','-23:49:34','B86';...
            '18:03:37','-24:23:12','M8';...
            '18:51:05.0','-06:16:12','M11';...
            '18:53:35.1','+33:01:45.0','M57';...
            '18:55:19.5','-30:32:43','SgrDwarf';...
            '20:45:38.0','+30:42:30','Veil';...
            '20:59:17.1','+44:31:44','NGC7000';...
            '22:29:38.55','-20:50:13.6','Helix';...
            '22:08:21','-11:28:19','Ecl1';...
            '22:27:20','-09:40:40','Ecl2';...
            '22:46:08','-07:49:09','Ecl3';...
            '23:04:45','-05:54:33','Ecl4';...
            '23:23:14','-03:57:38','Ecl5';...
            '23:41:38','-01:59:12','Ecl6';...
            '00:00:00','+00:00:00','Ecl7';...
            '00:18:21','+01:59:12','Ecl8';...
            '00:36:45','+03:57:38','Ecl9';...
            '00:55:14','+05:54:33','Ecl10';...
            '00:47:33','-25:17:18','NGC253';...
            '00:42:44.3','+41:16:09','M31';...
            '01:33:50.02','+30:39:36.7','M33';...
            '02:42:40.7','-00:00:47.84','M77';...
            '15:15:53','+56:10:40','NGC5907';...
            '16:06:03.9','+55:25:32','Tadpole';...
            '15:39:37.09','+59:19:55.02','NGC5985';...
            '19:40:42','+10:57:00','B142';...
            '19:06:06','-06:50:00','B133';...
            '19:21:38.936','+38:18:57.242','Kronberger61';...
            '01:36:41.8','+15:47:01','M74';...
            '01:21:46.8','+15:24:19','NGC488';...
            '01:24:35.0','+03:47:32.6','NGC520';...
            '05:34:31.94','+22:00:52.2','M1';...
            '05:35:17.3','-05:23:28','M42';...
            '05:40:59.0','-02:27:30.0','HorseHead'};
        
end

RA   = celestial.coo.convertdms(InPar.List(:,1),'gH','d');
Dec  = celestial.coo.convertdms(InPar.List(:,2),'gD','d');
Name = InPar.List(:,3);


% set exposure
C.ExpTime = InPar.ExpTime;
C.SaveOnDisk = true;
C.Display = [];


ObsCounter = zeros(size(RA));
ContObs = true;
LoopInd = 0;
while ContObs
    LoopInd = LoopInd + 1;
    % 1. calc Az/Alt/AM
    
    JD = celestial.time.julday;
    [AzAlt] = celestial.coo.horiz_coo([RA,Dec]./RAD,JD,[InPar.Lon InPar.Lat 0]./RAD);
    Az = AzAlt(:,1).*RAD;
    Alt = AzAlt(:,2).*RAD;
    AM = celestial.coo.hardie((90-Alt)./RAD);

    % 2. select western with AM<2 - select by min(Counter)
    Flag = find(AM<1.8);
    [~,MinInd] = min(ObsCounter(Flag));
    Ind = Flag(MinInd);

    if InPar.Verbose
        fprintf('Selected target: %s\n',Name{Ind});
    end
    
    % 3. observe: 20 x 15s
    TargetRA  = RA(Ind);
    TargetDec = Dec(Ind);
    
    % set telescope
    M.goto(RA(Ind),Dec(Ind));
    M.waitFinish;
    
    % take exposure
    for Iexp=1:1:InPar.Nexp
        C.takeExposure
        C.waitFinish;
    end
    

    % 3. add counter to target
    ObsCounter(Ind) = ObsCounter(Ind) + 1;

    Sun = celestial.SolarSys.get_sun(JD,[InPar.Lon, InPar.Lat]./RAD);
    if (Sun.Alt.*RAD)>-12 || exist(InPar.AbortFile,'file')
        ContObs = false;
    end
    % go to 1
end

