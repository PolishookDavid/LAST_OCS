% unit control system handle class
% Package: +obs/@unit
% Description: Operate a LAST unit - a mount + 4 telescopes + 4 focusers +
%              sensors.
% Input  : 
% Output : A unit class
%     By :
% Example: 
%
% Settings parameters options:
%

classdef unitCS < obs.LAST_Handle

    properties (Dependent)
        % mount direction and motion
        RA            % Deg
        Dec           % Deg
        HA
        Az
        Alt
        TrackingSpeed % Deg/s
        MountStatus
        
        % Cameras
        CameraStatus        % cell array of 4 values       
        Temperature         % Vector of Temp of 4 cameras
        ExpTime    = 1      % vector of 4 ExpTime
        ImType     = 'sci';
        Object     = '';
        
        % focusers
        Pos                % vector of 4 positions
        LastPos
        FocuserStatus      % cell array of 4 status
            
    end

    properties(GetAccess=public, SetAccess=private)
        % Mount configuration
        Status      = 'unknown';   % idle | busy | unknown
        IsEastOfPier = NaN;
    end

    properties(Hidden)
        %        
        Mount  obs.LAST_Handle    % handle to the mount(s) abstraction object
        Camera cell    % cell, handles to the camera abstraction objects
        Focuser cell   % cell, handles to the focuser abstraction objects
        HandleRemoteC    %
        CameraRemoteName char        = 'C';        
    end
 
    properties(GetAccess=public, SetAccess=?obs.LAST_Handle, Hidden)
        %these are set only when reading the configuration
        NodeNumber = 0;
        NumberLocalTelescopes
        NumberRemoteTelescopes
    end

    methods
        % constructor, destructor and connect
        function UnitObj=unitCS(id)
            % unit class constructor
            % Package: +obs/@unitCS
            if exist('id','var')
                UnitObj.Id=id;
            end
            % load configuration
            UnitObj.loadConfig(UnitObj.configFileName('create'))
            
            % populate mount, camera, focuser and power switches handles
            N=UnitObj.NumberLocalTelescopes;
            UnitObj.Mount=...
                obs.mount(sprintf('%d_%d',UnitObj.NodeNumber,1)); % for now always one (could be 0 for slave?)
            UnitObj.Camera=cell(1,N);
            UnitObj.Focuser=cell(1,N);
            for i=1:N
                UnitObj.Camera{i}=...
                    obs.camera(sprintf('%d_%d_%d',UnitObj.NodeNumber,1,i));
                UnitObj.Focuser{i}=...
                    obs.focuser(sprintf('%d_%d_%d',UnitObj.NodeNumber,1,i));
            end
        end
        

        function delete(UnitObj)
            % delete mount object and related sub objects (??)
%             delete(UnitObj.Mount);
%             delete(UnitObj.Camera);    
%             delete(UnitObj.Focuser);    
        end
                        
    end
    
    % setters/getters for children of the unit
    methods
        % general
        function Val=get.Status(UnitObj)
            % general status: idle | tracking | busy
            
            CheckFocuser = false;  % set to true in case you want to check also the focuser status
            
            % check status of all devices
            Val = 'busy';
            MS = UnitObj.MountStatus;
            if strcmp(MS,'idle') || strcmp(MS,'tracking')
                CamStatus = UnitObj.CameraStatus;
                if all(strcmp(CamStatus,'idle'))
                    if CheckFocuser
                        FocStatus = UnitObj.FocuserStatus;
                    else
                        FocStatus = {'idle'};
                    end
                    if all(strcmp(FocStatus,'idle'))
                        Val = MS;
                    end
                end
            end     
            
        end

        % queries the corresponding properties of the object in handle
        
        %--- Mount ---
        function Val=get.RA(UnitObj)
            Val = UnitObj.Mount.RA;
        end
       
        function set.RA(UnitObj,Val)
            UnitObj.Mount.RA = Val;
        end
       
        function Val=get.Dec(UnitObj)
            Val = UnitObj.Mount.Dec;
        end
       
        function set.Dec(UnitObj,Val)
            UnitObj.Mount.Dec = Val;
        end
        
        function Val=get.HA(UnitObj)
            Val = UnitObj.Mount.HA;
        end
       
        function set.HA(UnitObj,Val)
            UnitObj.Mount.HA = Val;
        end
        
        function Val=get.Az(UnitObj)
            Val = UnitObj.Mount.Az;
        end
       
        function set.Az(UnitObj,Val)
            UnitObj.Mount.Az = Val;
        end
        
        function Val=get.Alt(UnitObj)
            Val = UnitObj.Mount.Alt;
        end
       
        function set.Alt(UnitObj,Val)
            UnitObj.Mount.Alt = Val;
        end
        
        function Val=get.TrackingSpeed(UnitObj)
            % add description: vector of both axes, units in sidereal or what
            Val = UnitObj.Mount.TrackingSpeed;
        end
       
        function set.TrackingSpeed(UnitObj,Val)
            % add description: vector of both axes, units in sidereal or what
            UnitObj.Mount.TrackingSpeed = Val;
        end
        
        function Val=get.MountStatus(UnitObj)
            Val = UnitObj.Mount.Status;
        end

    end
    
    % setters/getters for camera(s)
    methods    
        %--- Camera ---
        function Val=get.CameraStatus(UnitObj)
            Val = UnitObj.getCameraProp('Status');
        end
        
        function Val=get.Temperature(UnitObj)
            Val = UnitObj.getCameraProp('Temperature');            
        end
        
        function set.Temperature(UnitObj,Val)
            % TODO
            error('set does not work yet');
        end
        
        function Val=get.ExpTime(UnitObj)
            Val = UnitObj.getCameraProp('ExpTime');
        end
            
        function set.ExpTime(UnitObj,Val)
            % TODO           
            error('set does not work yet');
        end   
       
       
    end
    
    % setters/getters for focuser(s) (children of abstract camera objects)
    methods
        function Val=get.Pos(UnitObj)
            Val = UnitObj.getCameraProp('Pos');
        end
        
        function set.Pos(UnitObj,Val)
            % If NaN then do not move focus
            error('set does not work yet');
        end
        
        function Val=get.LastPos(UnitObj)
            Val = UnitObj.getCameraProp('LastPos');
        end
        
        function Val=get.FocuserStatus(UnitObj)
            Val = UnitObj.getCameraProp('FocuserStatus');
        end
        
    end
        
    
end
