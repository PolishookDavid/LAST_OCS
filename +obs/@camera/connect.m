function success=connect(CameraObj, MountHn, FocusHn)
    % Open the connection with a specific camera, and
    %  read from it some basic information like color capability,
    %  physical dimensions, etc.
    %  cameranum: int, number of the camera to open (as enumerated by the SDK)
    %     May be omitted. In that case the last camera is referred to

   % Update computer clock using the Network Time Protocol (NTP)
   if CameraObj.Verbose, fprintf('>>> Updating computer clock with the Network Time Protocol (NTP).\n Wait for a few seconds\n'); end
   CameraObj.LogFile.writeLog('Updating computer clock with the Network Time Protocol (NTP).')
   util.update_time_NTP;
       
   if nargin>1
   % Open handle to mount
      CameraObj.MouHn=MountHn;
      MountConSuccess = CameraObj.MouHn.connect;
      CameraObj.LogFile.writeLog('Camera connects to mount to get details.')
      if(~MountConSuccess), fprintf('Failed to connect to Mount\n'); end
   end
   if nargin>2
   % Open handle to focuser
      CameraObj.FocHn=FocusHn;
      FocuserConSuccess = CameraObj.FocHn.connect;
      CameraObj.LogFile.writeLog('Camera connects to mount to derive details.')
      if(~FocuserConSuccess), fprintf('Failed to connect to Focuser\n'); end
   end

   % Connect to camera
   success = CameraObj.CamHn.connect;
   CameraObj.IsConnected = success;
   CameraObj.LogFile.writeLog('Connecting to camera.')

   if (success)

      % NEEDS TO ADD HERE AN ALGORITM TO CHOOSE WHICH CAMERA TO CONNECT TO. DP 22 Jun 2020
      % - Read 2 Unique names from config file,
      % - Compare with Unique Name read from camera.
      % - Define camera class instance as East or West

      
      CameraObj.cameranum = CameraObj.CamHn.cameranum;

      % Naming of instruments
      CameraNameDetails = strsplit(CameraObj.CamHn.CameraName);
      CameraObj.CamUniqueName = CameraNameDetails{end};
      if (strcmp(CameraObj.CamType, 'ZWO'))
         CameraObj.CamModel = CameraObj.CamHn.CameraName(1:strfind(CameraObj.CamHn.CameraName, CameraObj.CamUniqueName));
      elseif (strcmp(CameraObj.CamType, 'QHY'))
         CameraObj.CamModel = CameraObj.CamHn.CameraName(1:strfind(CameraObj.CamHn.CameraName, '-')-1);
      end
      
      % Read camera Geo name from config file
      CameraObj.CamGeoName = util.readSystemConfigFile('CamGeoName');


%       % Get searial number of last saved image
%       BaseDir = '/home/last/images/';
%       T = celestial.time.jd2date(floor(celestial.time.julday));
%       DirName = sprintf('%s%d%02d%02d',BaseDir, T(3), T(2), T(1));
%       if (exist(DirName,'dir'))
%          cd(DirName);
%          CameraObj.LastImageSearialNum = length(dir(['*',CameraObj.ImageFormat]));
%       else
%          CameraObj.LastImageSearialNum = 0;
%       end

      CameraObj.LogFile.writeLog('~~~~~~~~~~~~~~~~~~~~~~')
      CameraObj.LogFile.writeLog('Details:')
      CameraObj.LogFile.writeLog(sprintf('CamType: %s',CameraObj.CamType))
      CameraObj.LogFile.writeLog(sprintf('CamModel: %s',CameraObj.CamModel))
      CameraObj.LogFile.writeLog(sprintf('CamUniqueName: %s',CameraObj.CamUniqueName))
      CameraObj.LogFile.writeLog(sprintf('CamGeoName: %s',CameraObj.CamGeoName))
      CameraObj.LogFile.writeLog('~~~~~~~~~~~~~~~~~~~~~~')

   else
      switch CameraObj.CamHn.lastError
      case "could not even get one camera id"
         CameraObj.lastError = "Could not even get one camera id";
         if CameraObj.Verbose, fprintf('%s\n', CameraObj.lastError); end
         CameraObj.LogFile.writeLog(CameraObj.lastError)
      end
   end
   
   
end
