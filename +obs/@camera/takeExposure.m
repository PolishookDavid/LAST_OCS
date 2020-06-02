function takeExposure(CameraObj,expTime)

   if exist('expTime','var')
      CameraObj.ExpTime=expTime;   
   end
   
   % Check mount status
   if (~strcmp(CameraObj.MountHndl.Status, 'slewing'))
      % Send exposure command
      CameraObj.CameraDriverHndl.takeExposure(CameraObj.ExpTime);

      % Start timer to write image on disk and display it when exposure and reading are complete
      CameraObj.ReadoutTimer = timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Name', 'camera-timer', 'Period', 1, 'StartDelay', 1, 'TimerFcn', @CameraObj.callback_timer, 'ErrorFcn', 'beep');
      start(CameraObj.ReadoutTimer);
   end
end