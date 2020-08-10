function Flag = takeExposure(CameraObj,ExpTime)
% take single exposure method
% Package: +obs.@mount
% Input  : - A camera object.
%          - Exposure time [s].
% Output : - Sucess flag.


   if CameraObj.IsConnected
      Flag = false;
       
      if nargin == 2
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
         Flag = true;
         %   end
      else
         if CameraObj.Verbose, fprintf('Cannot take exposure, still processing previous image. Please wait\n'); end
         CameraObj.LogFile.writeLog('Cannot take exposure, still processing previous image. Please wait')
         Flag = false;
      end
   else
      CameraObj.LastError = 'Warnning: Camera is disconnected';
   end
end