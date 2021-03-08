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
        HandleCamera     % 4 elements of camera handles
        
        MountConfigStruct struct     = struct();
        CameraConfigStruct struct    = struct();
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
            delete(UnitObj.HandleFocuser);
            delete(UnitObj.HandleMount);
            delete(UnitObj.HandleCamera);
            
        end
        
        function UnitObj=disconnect(UnitObj)
            % disconnect all objects
            
            UnitObj.HandleMount.disconnect;
            for I=1:1:numel(UnitObj.HandleCamera)
                UnitObj.HandleCamera(I).HandleFocuser.disconnect;
                UnitObj.HandleCamera(I).disconnect;
            end
        end
        
        function UnitObj=connect(UnitObj,varargin)
            %
            
            
            InPar = inputParser;
            addOptional(InPar,'AddressMount',[1 1]);
            addOptional(InPar,'CameraNumber',3); %[1 3]);
            
            parse(InPar,varargin{:});
            InPar = InPar.Results;
            
            MountConfigStruct = readConfig(UnitObj,InPar.AddressMount,...
                                    'config.mount','MountName');
                                
            Ncam = numel(InPar.CameraNumber);
            for Icam=1:1:Ncam
                CameraConfigStruct(Icam) = readConfig(UnitObj,[InPar.AddressMount, InPar.CameraNumber(Icam)],...
                                    'config.camera','CameraName');
            end
                
            UnitObj.MountConfigStruct  = MountConfigStruct;
            UnitObj.CameraConfigStruct = CameraConfigStruct;
            
            % connect to mount
            M = obs.mount(MountConfigStruct.MountType);
            M.connect(InPar.AddressMount);
            
            % connect to focuser
            for Icam=1:1:Ncam
                F(Icam) = obs.focuser;
                F(Icam).connect;
            end
            
            % connect to camera
            for Icam=1:1:Ncam
                C(Icam) = obs.camera(CameraConfigStruct(Icam).CameraType);
                C(Icam).connect([InPar.AddressMount, InPar.CameraNumber(Icam)]);
                C(Icam).HandleMount  = M;
                C(Icam).HandleFocuser = F;
            end
            
            UnitObj.HandleMount  = M;
            UnitObj.HandleCamera = C;
                
        end
        
    end
    
    % setters/getters for mount
    methods
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
            
            Ncam = numel(UnitObj.HandleCamera);
            Val  = cell(1,Ncam);
            for Icam=1:1:Ncam
                Val{Icam} = UnitObj.HandleCamera(Icam).Status;
            end
        end
        
        function Val=get.Temperature(UnitObj)
            % getters
           
            Ncam = numel(UnitObj.HandleCamera);
            Val  = nan(1,Ncam);
            for Icam=1:1:Ncam
                Val(Icam) = UnitObj.HandleCamera(Icam).Temperature;
            end
        end
        
        function set.Temperature(UnitObj,Val)
            % setters
           
            Ncam = numel(UnitObj.HandleCamera);
            if numel(Val)==1
                Val = Val + zeros(1,Ncam);
            end
            if numel(Val)~=Ncam
                error('Number of Temperature must be 1 or equal to the number of cameras: %d',Ncam);
            end
            for Icam=1:1:Ncam
                UnitObj.HandleCamera(Icam).Temperature = Val(Icam);
            end
            
        end
        
        function Val=get.ExpTime(UnitObj)
            % getters
           
            Ncam = numel(UnitObj.HandleCamera);
            Val  = nan(1,Ncam);
            for Icam=1:1:Ncam
                Val(Icam) = UnitObj.HandleCamera(Icam).ExpTime;
            end
        end
            
        function set.ExpTime(UnitObj,Val)
            % getters
           
            Ncam = numel(UnitObj.HandleCamera);
            if numel(Val)==1
                Val = Val + zeros(1,Ncam);
            end
            if numel(Val)~=Ncam
                error('Number of ExpTime must be 1 or equal to the number of cameras: %d',Ncam);
            end
            for Icam=1:1:Ncam
                UnitObj.HandleCamera(Icam).ExpTime = Val(Icam);
            end
        end   
       
       
    end
    
    % setters/getters for focuser
    methods
        %--- Focuser ---
        function Val=get.Pos(UnitObj)
            % getters
            
            Ncam = numel(UnitObj.HandleCamera);
            Val  = nan(1,Ncam);
            for Icam=1:1:Ncam
                Val(Icam) = UnitObj.HandleCamera(Icam).HandleFocuser.Pos;
            end
            
        end
        
        function set.Pos(UnitObj,Val)
            % setters
            % If NaN then do not move focus
           
            Ncam = numel(UnitObj.HandleCamera);
            if numel(Val)==1
                Val = Val + zeros(1,Ncam);
            end
            if numel(Val)~=Ncam
                error('Number of Pos must be 1 or equal to the number of cameras: %d',Ncam);
            end
            for Icam=1:1:Ncam
                if ~isnan(Val(Icam))
                    UnitObj.HandleCamera(Icam).Status = Val(Icam);
                end
            end
            
        end
        
        function Val=get.FocuserStatus(UnitObj)
            % getters
            
            Ncam = numel(UnitObj.HandleCamera);
            Val  = cell(1,Ncam);
            for Icam=1:1:Ncam
                Val{Icam} = UnitObj.HandleCamera(Icam).Status;
            end
        end
        
    end
    
    % general functions
    methods 
        function varargout=goto(UnitObj,varargin)
            % goto - see obs.mount.goto
            
            [varargout{1:1:nargout}] = UnitObj.HandleMount.goto(varargin{:});
        end
        
        function Flag=takeExposure(UnitObj,ExpTime,Nimages)
            % takeExposure (see also obs.camera.takeExposure)
            % Input  : - A unit object
            %        : - A vector of Exposure times, one per camera
            %            If scalar, then set all ExpTime to the same value.
            %            If not given then use ExpTime property.
            %          - Vector of number of images per camera.
            %            If scalar, then use the same number for all
            %            cameras. Default is 1.
            
            % Flag=takeExposure(CameraObj,ExpTime,Nimages,WaitFinish)
            
            Ncam = numel(UnitObj.HandleCamera);
            if numel(ExpTime)==1
                ExpTime = ExpTime + zeros(1,Ncam);
            end
            if numel(Nimages)==1
                Nimages = Nimages + zeros(1,Ncam);
            end
            
            error('takeExposure not ready');
            for Icam=1:1:Ncam
                
                Flag(Icam) = UnitObj.HandleCamera.takeExposure();
            end
        end
        
        
    end
    
    
end
