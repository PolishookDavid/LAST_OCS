function rc = test_OCS_opperation()
%% Check operational status of the system

% Connect to mount
M = obs.mount; rc = M.connect;
if(~rc), fprintf('Mount: connect failed\n'); end
% Connect to focuser
F = obs.focuser('Robot'); rc = F.connect;
if(~rc), fprintf('Focuser: connect failed\n'); end
% connect to camera
C = obs.camera('QHY'); rc = C.connect(M, F);
if(~rc), fprintf('Camera: connect failed\n'); end

%% check Mount motion
fprintf('**************\n')
fprintf('Checking mount\n')
fprintf('>>> Go home\n')
M.home; rc = M.waitFinish;
if(~rc), fprintf('Mount: home failed\n'); end
if(M.Dec ~= 90), fprintf('Mount: Not at home\n'); end
fprintf('>>> set Dec\n')
M.Dec = 87; rc = M.waitFinish;
if(~rc), fprintf('Mount: Dec setter failed\n'); end
RA  = M.RA;
fprintf('RA is %f\n', RA)
fprintf('>>> set RA\n')
LST=celestial.time.lst(celestial.time.julday,34/180*pi)*360
M.RA = LST - 5; rc = M.waitFinish;
if(~rc), fprintf('Mount: RA setter failed\n'); end
Az = M.Az;
fprintf('>>> set Az\n')
M.Az = Az + 5; rc = M.waitFinish;
if(~rc), fprintf('Mount: Az setter failed\n'); end
Alt = M.Alt;
fprintf('>>> set Alt\n')
M.Alt = Alt + 5; rc = M.waitFinish;
if(~rc), fprintf('Mount: Alt setter failed\n'); end
RA = M.RA;
Dec = M.Dec;
fprintf('>>> use goto\n')
M.goto(RA - 5, Dec - 5); rc = M.waitFinish;
if(~rc), fprintf('Mount: goto failed\n'); end
fprintf('>>> Go home\n')
M.home; rc = M.waitFinish;
if(~rc), fprintf('Mount: home failed\n'); end
fprintf('Check mount done\n')



%% Check focuser motion
fprintf('****************\n')
fprintf('Checking focuser\n')
CurPos = F.Pos;
if (~isnumeric(F.Pos)), fprintf('Focuser: Pos getter failed\n'); end
fprintf('>>> run relPos\n')
F.relPos(500); rc = F.waitFinish;
if(~rc), fprintf('Focuser: relPos failed\n'); end
fprintf('>>> set Pos\n')
F.Pos = CurPos; rc = F.waitFinish;
if(~rc), fprintf('Focuser: Pos setter failed\n'); end
fprintf('Check focuser done\n')


% Check camera
fprintf('***************\n')
fprintf('Checking camera\n')
C.ExpTime = 5;
% Take exposure
rc = C.takeExposure;
if(~rc), fprintf('Camera: takeExposure failed\n'); end
rc = C.waitFinish;
if(~rc), fprintf('Camera: Exposure failed\n'); end
%--- load image ---
S = FITS.read2sim(C.LastImageName);
[row,col] = size(S.Im);
if (row*col == 0), fprintf('Camera: image empty\n'); end
if (mean(mean(S.Im)) == 0), fprintf('Camera: image empty\n'); end
H = S.Header;
[row, col] = size(H);
for I=1:1:row, if(strcmp(H{I,1}, 'DATE-OBS')),J = I; end; end
fprintf('DATE-OBS = %s\n', H{J,2,1})
title(H{J,2,1})

C.Display = 'ds9';
rc = C.takeExposure;
if(~rc), fprintf('Camera: takeExposure failed\n'); end
rc = C.waitFinish;
if(~rc), fprintf('Camera: Exposure failed\n'); end

fprintf('Check camera done\n')
