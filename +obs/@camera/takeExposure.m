function takeExposure(CameraObj,ExpTime)

   if exist('expTime','var')
      CameraObj.ExpTime=ExpTime;
   end
   
   if(strcmp(CameraObj.CamStatus, 'idle'))
   
   % Check mount status - OBSELETE?
%   if (~strcmp(CameraObj.MouHn.Status, 'slewing'))

      % Send exposure command
      CameraObj.CamHn.takeExposure(CameraObj.ExpTime);
      CameraObj.LogFile.writeLog(sprintf('call takeExposure. ExpTime=%.3f', CameraObj.ExpTime))

      % Start timer to write image on disk and display it when exposure and reading are complete
      CameraObj.ReadoutTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'camera-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @CameraObj.callback_timer, 'ErrorFcn', 'beep');
      start(CameraObj.ReadoutTimer);
      CameraObj.LogFile.writeLog('Start image readout timer')
%   end
   else
      if CameraObj.Verbose, fprintf('Cannot take exposure, still processing previous image. Please wait\n'); end
      CameraObj.LogFile.writeLog('Cannot take exposure, still processing previous image. Please wait')
   end
end