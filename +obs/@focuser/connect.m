function success=connect(Focuser,Port)
% Connect to a focus motor

   ConfigNode=obs.util.config.read_config_file('/home/last/config/config.node.txt');
   ObservatoryNode = ConfigNode.ObservatoryNode;
   ConfigMount=obs.util.config.read_config_file('/home/last/config/config.mount.txt');
   MountGeoName = ConfigMount.MountGeoName;
   ConfigCam=obs.util.config.read_config_file('/home/last/config/config.mount.txt');
   % PATCH: At this stage there is no camera attributed to the camera - need to solve this. DP Dec 2020
   CamGeoName = '';
   FocuserUniqueName = ConfigCam.FocuserUniqueName;
   
   DirName = obs.util.config.constructDirName('log');
   cd(DirName);

   % Opens Log for the camera
   Focuser.LogFile = logFile;
   Focuser.LogFile.Dir = DirName;
   Focuser.LogFile.FileNameTemplate = 'LAST_%s.log';
   Focuser.LogFile.logOwner = sprintf('%s.%s.%s_%s_Foc', ...
                                  ObservatoryNode, MountGeoName, CamGeoName, DirName(end-7:end));
%                                  obs.util.config.readSystemConfigFile('ObservatoryNode'), obs.util.config.readSystemConfigFile('MountGeoName'), obs.util.config.readSystemConfigFile('CamGeoName'), DirName(end-7:end));


    success = 0;
    if nargin == 1
       Focuser.Handle.connect;
    elseif(nargin == 2)
       Focuser.Handle.connect(Port);
    end
    Focuser.LogFile.writeLog('Connecting to focuser.')
    Focuser.LogFile.writeLog(sprintf('Current focus position: %d',Focuser.Pos));


    % Get name and type
%    Focuser.FocuserUniqueName = obs.util.config.readSystemConfigFile('FocuserUniqueName');
    Focuser.FocuserUniqueName = FocuserUniqueName;
    Focuser.FocuserType = Focuser.Handle.FocType;

    if (isempty(Focuser.Handle.LastError))
       success = 1;
    end
    Focuser.LastError = Focuser.Handle.LastError;
end
