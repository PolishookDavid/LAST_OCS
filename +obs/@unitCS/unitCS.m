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

classdef unitCS <obs.LAST_Handle

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
        HandleMount      % mount handle
        HandleCamera     %
        HandleRemoteC    %
        CameraRemoteName char        = 'C';
        
        MountConfigStruct struct     = struct();
        CameraConfigStruct struct    = struct();
        
        Verbose logical              = true;
    end
    

    methods
        % constructor, destructor and connect
        function MountObj=unitCS()
            % mount class constructor
            % Package: +obs/@mount
            % Input  : - Mount type ['xerxes'] | 'ioptron'
            %
            
          
            
%             if nargin >= 1
%               % Derive mount type from the user
%               MountObj.MountType = MountType;
%             else
%               % Use Xerxes mount as default
%               MountObj.MountType = 'Xerxes';
%             end
% 
%             % Open a driver object for the mount
%             switch lower(MountObj.MountType)
%                 case 'xerxes'
%                     MountObj.Handle=inst.XerxesMount();
%                 case 'ioptron'
%                     MountObj.Handle=inst.iOptronCEM120();
%                 otherwise
%                     error('Unknown MountType');
%             end
            
        end
        

        function delete(UnitObj)
            % delete mount object and related sub objects
            delete(UnitObj.HandleMount);
            delete(UnitObj.HandleCamera);
            
        end
        
        function UnitObj=disconnect(UnitObj)
            % disconnect all objects
            
            for I=1:1:numel(UnitObj.HandleCamera)
                UnitObj.HandleCamera(I).HandleFocuser.disconnect;
                UnitObj.HandleCamera(I).disconnect;
            end
            UnitObj.HandleMount.disconnect;
        end
        
        function Obj=connect(Obj,varargin)
            %
            
            
            InPar = inputParser;
            addOptional(InPar,'MountType','Xerxes');
            addOptional(InPar,'AddressMount',[1 1]);
            addOptional(InPar,'Ncam',2);
            %addOptional(InPar,'CameraNumber',[1 3]); %[1 3]);
            addOptional(InPar,'CameraRemote',[]); %[1 3]);
            addOptional(InPar,'CameraType','QHY');
            addOptional(InPar,'CameraRemoteName','C');  % if empty then do not populate
            parse(InPar,varargin{:});
            InPar = InPar.Results;
                        
            if Obj.Verbose
                fprintf('Connect to mount Node=%d, Mount=%d\n',InPar.AddressMount);
            end
            
            M = obs.mount(InPar.MountType);
            M.connect(InPar.AddressMount);
            
            % connect to fcusers and cameras
            C = obs.camera(InPar.CameraType,InPar.Ncam);
            C.connect('all');
            Ncam = numel(C);
            
            pause(3);
               
            
            for Icam=1:1:Ncam
                F(Icam) = obs.focuser;
                F(Icam).connect([InPar.AddressMount C(Icam).CameraNumber]);
                % assign focuser to camera using CameraNumber
                C(Icam).HandleFocuser = F(Icam);
            end
            
            
            
            
            if ~isempty(InPar.CameraRemoteName)
                Obj.CameraRemoteName = InPar.CameraRemoteName;
            end
            
            % connect remote cameras
            if isempty(InPar.CameraRemote)
                RemoteC = [];
            else
                RemoteC      = InPar.CameraRemote; % This should be a connected object
                RemoteC.Name = Obj.CameraRemoteName;
                
            end
            
            Obj.HandleMount   = M;
            Obj.HandleCamera  = C;
            Obj.HandleRemoteC = RemoteC;
            
            
            
                
        end
        
        function Val=getCameraProp(Obj,Prop)
            % a general getter for camera property
            % Example: Obj.getCameraProp('ExpTime');
            
            % get info from remote cameras
            % check how many cameras are remotely connected
            if isempty(Obj.HandleRemoteC)
                Nrc = 0;
            else
                Nrc = Obj.classCommand(Obj.HandleRemoteC,'numel','(1:end)');
            end
            Nc  = numel(Obj.HandleCamera);
            
            Ind = 0;
            % get remote prop
            for Irc=1:1:Nrc
                Ind = Ind + 1;
                Tmp = Obj.classCommand(Obj.HandleRemoteC,Prop,Irc);
                if ischar(Tmp)
                    Val{Ind} = Tmp;
                elseif isnumeric(Tmp)
                    Val(Ind) = Tmp;
                else
                    error('Unknown classCommand return option');
                end
            end
            
            for Ic=1:1:Nc
                Ind = Ind + 1;
                Tmp = Obj.HandleCamera(Ic).(Prop);
                if ischar(Tmp)
                    Val{Ind} = Tmp;
                elseif iscellstr(Tmp)
                    Val{Ind} = Tmp{1};
                elseif isnumeric(Tmp)
                    Val(Ind) = Tmp;
                else
                    error('Unknown classCommand return option');
                end
            end
            
            
        end
        
        
    end
    
    % setters/getters for mount
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
        
        %--- Mount ---
        function Val=get.RA(UnitObj)
            % getters
            
            Val = UnitObj.HandleMount.RA;
        end
       
        function set.RA(UnitObj,Val)
            % setters
            
            UnitObj.HandleMount.RA = Val;
        end
       
        function Val=get.Dec(UnitObj)
            % getters
            
            Val = UnitObj.HandleMount.Dec;
        end
       
        function set.Dec(UnitObj,Val)
            % setters
            
            UnitObj.HandleMount.Dec = Val;
        end
        
        function Val=get.HA(UnitObj)
            % getters
            
            Val = UnitObj.HandleMount.HA;
        end
       
        function set.HA(UnitObj,Val)
            % setters
            
            UnitObj.HandleMount.HA = Val;
        end
        
        function Val=get.Az(UnitObj)
            % getters
            
            Val = UnitObj.HandleMount.Az;
        end
       
        function set.Az(UnitObj,Val)
            % setters
            
            UnitObj.HandleMount.Az = Val;
        end
        
        function Val=get.Alt(UnitObj)
            % getters
            
            Val = UnitObj.HandleMount.Alt;
        end
       
        function set.Alt(UnitObj,Val)
            % setters
            
            UnitObj.HandleMount.Alt = Val;
        end
        
        function Val=get.TrackingSpeed(UnitObj)
            % getters
            
            Val = UnitObj.HandleMount.TrackingSpeed;
        end
       
        function set.TrackingSpeed(UnitObj,Val)
            % setters
            
            UnitObj.HandleMount.TrackingSpeed = Val;
        end
        
        function Val=get.MountStatus(UnitObj)
            % getters
            
            Val = UnitObj.HandleMount.Status;
        end
        
        
    end
    
    % setters/getters for camera
    methods    
        %--- Camera ---
        function Val=get.CameraStatus(UnitObj)
            % getters
            
            Val = UnitObj.getCameraProp('Status');
            
        end
        
        function Val=get.Temperature(UnitObj)
            % getters
           
            Val = UnitObj.getCameraProp('Temperature');
            
        end
        
        function set.Temperature(UnitObj,Val)
            % setters
           
            error('set does not work yet');
            
        end
        
        function Val=get.ExpTime(UnitObj)
            % getters
           
            Val = UnitObj.getCameraProp('ExpTime');
            
        end
            
        function set.ExpTime(UnitObj,Val)
            % setters
           
            error('set does not work yet');
            
        end   
       
       
    end
    
    % setters/getters for focuser
    methods
        %--- Focuser ---
        function Val=get.Pos(UnitObj)
            % getters
            
            Val = UnitObj.getCameraProp('Pos');

        end
        
        function set.Pos(UnitObj,Val)
            % setters
            % If NaN then do not move focus
           
            error('set does not work yet');
            
            
        end
        
        function Val=get.LastPos(UnitObj)
            % getters
            
            Val = UnitObj.getCameraProp('LastPos');

        end
        
        function Val=get.FocuserStatus(UnitObj)
            % getters
            Val = UnitObj.getCameraProp('FocuserStatus');
            
        end
        
    end
    
    % general functions
    methods 
        function varargout=goto(UnitObj,varargin)
            % goto - see obs.mount.goto
            
            [varargout{1:1:nargout}] = UnitObj.HandleMount.goto(varargin{:});
        end
        
        function Flag=takeExposure(UnitObj,varargin)
            % takeExposure (see also obs.camera.takeExposure)
            % Input  : - A unit object.
            %          - Exposure time [s]. If provided this will override
            %            the CameraObj.ExpTime, and the CameraObj.ExpTime
            %            will be set to this value.
            %          - Number of images to obtain. Default is 1.
            %          * ...,key,val,...
            %            'WaitFinish' - default is true.
            %            'SaveMode' - default is 2.
            %            'ImType' - default is [].
            %            'Object' - default is [].
            % Example: U.takeExposure(1,1);
            
            % start exposure on remote cameras
            
            
            % start exposures on local cameras
            
            %set ImType and Object
            
            Flag = UnitObj.HandleCamera.takeExposure(varargin{:});
            
        end
        
        
    end
    
    
end
