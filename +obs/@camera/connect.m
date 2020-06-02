function success=connect(CameraObj)
    % Open the connection with a specific camera, and
    %  read from it some basic information like color capability,
    %  physical dimensions, etc.
    %  cameranum: int, number of the camera to open (as enumerated by the SDK)
    %     May be omitted. In that case the last camera is referred to
   
   % Update computer clock using the Network Time Protocol (NTP)
   util.update_time_NTP;

   success = CameraObj.CameraDriverHndl.connect;
   if (success)
      CameraObj.cameranum = CameraObj.CameraDriverHndl.cameranum;

      % Naming of instruments
      CameraNameDetails = strsplit(CameraObj.CameraDriverHndl.CameraName);
      CameraObj.CamUniqueName = CameraNameDetails{end};
      CameraObj.CamType = 'ZWO';
      CameraObj.CamModel = CameraObj.CameraDriverHndl.CameraName(1:strfind(CameraObj.CameraDriverHndl.CameraName, CameraObj.CamUniqueName));

      % Read camera Geo name from config file
      CameraObj.CamGeoName =            util.readSystemConfigFile('CamGeoName');
      
      % Open handles to mount and focuser
      CameraObj.MountHndl = obs.mount;
      MountConSuccess = CameraObj.MountHndl.connect;
%       if(~MountConSuccess), fprintf('Failed to connect to Mount\n'); end
%       CameraObj.FocuserHndl = obs.focuser;
%       FocuserConSuccess = CameraObj.FocuserHndl.connect;
%       if(~FocuserConSuccess), fprintf('Failed to connect to Focuser\n'); end

      % Get searial number of last saved image
      BaseDir = '/home/last/images/';
      T = celestial.time.jd2date(floor(celestial.time.julday));
      DirName = sprintf('%s%d%02d%02d',BaseDir, T(3), T(2), T(1));
      if (exist(DirName,'dir'))
         cd(DirName);
         CameraObj.LastImageSearialNum = length(dir(['*',CameraObj.SavedImagesType]));
      else
         CameraObj.LastImageSearialNum = 0;
      end
   else
      switch CameraObj.CameraDriverHndl.lastError
      case "could not even get one camera id"
          CameraObj.lastError = "could not even get one camera id";
      end
   end
   
   
end
