%function connect_session
%


%X = inst.XerxesMount;
%X.connect
% M = obs.mount;
% M.connect([1 1]);
% 
% F = obs.focuser;
% F.connect
% 
% C = obs.camera;
% C.connect([1 1 3]);
% 

%%

% session 1
% Mount + mount listener

MsgM = obs.util.Messenger('localhost',23013,22013)  % destination, local
MsgM.connect
M    = obs.mount('Xerxes');
M.connect([1 1]);


% session 2
% Camera
C    = obs.camera('QHY');
C.connect([1 1 3]);









%%
Node  = 1;
Mount = 1;
Camera  = 3; %[1 2];

% get computer number:
HomeDir = getenv('HOME');
SpDir   = split(HomeDir,filesep);
User    = SpDir{end};

try
    ComputerNumber = str2double(User(5:6));
catch
    ComputerNumber = 1;
end


Ncam = numel(Camera);

% mount
% focuser1
% focuser2
% camera1
% camera2
% unitCS

% connect to mount
M = obs.mount('Xerxes');
M.connect([Node Mount]);


% connect to focuser
for Icam=1:1:Ncam
    F(Camera(Icam)) = obs.focuser; % Camera?
    F(Camera(Icam)).connect
end

% connect to camera
for Icam=1:1:Ncam
    C(Camera(Icam)) = obs.camera('QHY');
    C(Camera(Icam)).connect([Node Mount Camera(Icam)]);
end

% open task listener on session
% always assume that each mount is connected to ComputerNumbers which are:
% one odd and one even
DestinationPort = obs.remoteClass.construct_port_number('computer', Mount,Camera);

% or
% focuser3
% focuser4
% camera3
% camera4