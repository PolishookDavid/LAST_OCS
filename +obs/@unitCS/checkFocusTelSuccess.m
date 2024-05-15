function [RC]=checkFocusTelSuccess(Unit,CameraInx,FocusTelStartTime,FocusLoopTimeout)
% Examine the results of focusTel per camera
%
% CameraInx - the index of the camera to examine [1, 2, 3 or 4]
% FocusLoopTimeout - time out value to wait for the focus loop to conclude
% [seconds]
% Written by David Polishook, Jan 2023


arguments
    Unit
    CameraInx
    FocusTelStartTime
    FocusLoopTimeout
end

% Focus log legend
Col.Camera = 1;
Col.JD = 2;
Col.temp1 = 3;
Col.temp2 = 4;
Col.Success = 5;
Col.BestPos = 6;
BestFWHM = 7;
Col.BackLashOffset = 8;

RC = 0;
%Timeout = 0;
Timeout = (celestial.time.julday-FocusTelStartTime)*24*3600;
HostName = tools.os.get_computer;
FocusLogBaseFileName = ['log_focusTel_M',HostName(6),'C',int2str(CameraInx),'.txt'];
FocusLogDirFileName = [pipeline.last.constructCamDir(CameraInx,'SubDir','log'),'/', FocusLogBaseFileName];
while (~exist(FocusLogDirFileName, 'file') && Timeout < FocusLoopTimeout)
   % Wait until file exist or reaching timeout
   Unit.abortablePause(10);
   Timeout = (celestial.time.julday-FocusTelStartTime)*24*3600;
end
if(~exist(FocusLogDirFileName, 'file'))
   fprintf('Focus log file of camera %d not found.\n', CameraInx)
else
   %Timeout = 0;
   FocusLog = load(FocusLogDirFileName);
   % Wait 10 seconds as long as the log was written before the focusloop start run time (i.e. it's an old log)
   while (FocusTelStartTime > FocusLog(Col.JD) && Timeout < FocusLoopTimeout)
      Unit.abortablePause(10);
      %Timeout = Timeout + 10;
      Timeout = (celestial.time.julday-FocusTelStartTime)*24*3600;
      FocusLog = load(FocusLogDirFileName);
   end
   if (Timeout < FocusLoopTimeout)
      % if while loop is finished NOT due to the timeout - use the success
      % value in the log file
      RC = FocusLog(Col.Success);
   end
end
