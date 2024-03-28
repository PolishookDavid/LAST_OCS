% unit control system handle class
% Package: +obs/@webunit
% Description: Operate a LAST unit - a mount + 4 telescopes + 4 focusers +
%              sensors.
% Input  : 
% Output : A unit class
%     By : Enrico
% Example: 
%
% Settings parameters options:
%

classdef webunit < obs.LAST_Handle

    properties (Description='api')
        Connected; % untyped, because the setter may receive a logical or a string
    end

    % these are filled canonically by the constructor
    properties (GetAccess=public, SetAccess=private)
        Mount    obs.api.wrappers.mount % handle to the mount(s) abstraction object
        Camera   obs.api.wrappers.camera % handles to the camera abstraction objects
        Focuser  obs.api.wrappers.focuser % handles to the focuser abstraction objects
        PowerSwitch  cell   % handles to IP power switches units
    end

    properties (Description='api')
        MountPower logical % power of the mount, off/on
        CameraPower logical % power of the cameras off/on
    end
    
    % these are typically read from the configuration, and never changed
    properties(Hidden)
        CameraPowerUnit double =[]; % switch unit controlling each camera
        CameraPowerOutput double =[]; % switch output controlling each camera
        MountPowerUnit double =[];% switch controlling mount power
        MountPowerOutput double=[]; % switch output controlling the mount
        MountNumber            = 99;  % Mount number 1..12 - 99=unknown (currently taken from Id)
        NumLocalTelescopes=2;
        NumRemoteTelescopes=0;
        Timezone=2;
    end

    properties(GetAccess=public, SetAccess=private, Description='api')
        Temperature double; % temperature reading from the IPswitch 1wire sensors
        Status struct; % structure holding the status of all components
    end


    methods
        % constructor, destructor
        function U=webunit(Locator)
            % identify the unit by locator
            if exist('Locator','var')
                if isa(Locator,'obs.api.Locator')
                    id = Locator.Canonical;
                elseif isa(Locator,'char') || isa(Locator,'string')
                    L=obs.api.Locator('Location',Locator);
                    id=L.Canonical;
                else
                    id='';
                end
            else
                id=''; % will cause error below
            end
            U.Id=id;
            % fill initial status of untyped .Connected
            U.Connected=false;
            % load configuration
            U.loadConfig(U.configFileName('create'))
            % this one is read in as string and converted, because of limitations of
            %  Astropack's yml reader
            %             U.RemoteTelescopes=eval(U.RemoteTelescopes);
            %
            % Populate mount, camera, focuser and power switches handles
            % NB: it would be sensible and elegant to construct locators
            %     using the relevant arguments of the constructor, e.g.
            %
            %  obs.api.Locator('ProjectName',U.ProjectName,...
            %                  'NodeId',U.NodeId,...
            %                  'MountId',U.MountId,'EquipType','Mount');
            %
            % but parsing of the arguments is yet imperfect. (see
            % https://github.com/blumzi/LAST_Api/issues/29). Thus, for the
            %  time being I construct strings, which is less elegant and
            %  more fragile
            
            % regenerate (in case passed as string) the full locator of
            % the unit
            %L=obs.api.Locator('Location',id);
            projectnode=sprintf('%s.%d', L.ProjectName, L.NodeId);
            % switches:
            U.PowerSwitch=cell(1,2);
            for j=1:2
                U.PowerSwitch{j}=...
                    inst.tinycontrolIPpowerSocket(sprintf('%d_%d',L.UnitId,j));
            end
            % for now always one mount per unit (or, empty mount when absent)
            U.Mount=obs.api.makeHttpApi('Location',...
                sprintf('%s.unit%de.mount', projectnode, L.UnitId));
            % create camera and focuser objects for local telescopes
            % sides hardwired for the moment, locator parsing has bugs
            for j=1:U.NumLocalTelescopes + U.NumRemoteTelescopes
                U.Camera(j)=obs.api.makeHttpApi('Location',...
                    sprintf('%s.unit%d.camera%d',projectnode,L.UnitId,j));
                U.Focuser(j)=obs.api.makeHttpApi('Location',...
                    sprintf('%s.unit%d.focuser%d',projectnode,L.UnitId,j));
            end
            
        end
        

        function delete(U)
            % delete unit object and related sub objects
% Be careful. Since the resources for each child are in fact unique (fixed
%  udp port numbers, fixed switch, focuser, mount), it can very well
%  happen that the destructor of an old object is called just after
%  a new one is created, causing hardware to be turned off immediately
%  after it is turned on, if the specific delete() includes that.
            if U.Connected
                U.disconnect;
            end
            delete(U.Mount);
            for i=1:numel(U.Camera)
                delete(U.Camera{i});
            end
            for i=1:numel(U.Focuser)
                delete(U.Focuser{i});
            end
            for i=1:numel(U.PowerSwitch)
                delete(U.PowerSwitch{i});
            end
        end

    end
    
    % setters/getters
    methods

        function set.Connected(U,tf)
            % when called via the API, the argument is received as a string
            if isa(tf,'string')
                tf=eval(tf);
            end
            if isempty(U.Connected)
                U.Connected=false;
            end
            % don't try to connect if already connected, as per API wiki
            if ~U.Connected && tf
                U.Connected=U.connect;
            elseif U.Connected && ~tf
                U.Connected=~U.disconnect;
            end
        end


        function status=get.Status(U)
            try
                if U.Mount.Connected
                    status.Mount=U.Mount.Status;
                else
                    status.Mount='disconnected';
                end
            catch
                status.Mount='unreachable';
            end
            %
            status.Camera=cell(1,numel(U.Camera));
            for i=1:numel(U.Camera)
                try
                    if U.Camera(i).Connected
                        status.Camera{i}=U.Camera(i).CamStatus;
                    else
                        status.Camera{i}='disconnected';
                    end
                catch
                    status.Camera{i}='unreachable';
                end
            end
            %
            status.Focuser=cell(1,numel(U.Focuser));
            for i=1:numel(U.Focuser)
                try
                    if U.Focuser(i).Connected
                        status.Focuser{i}=U.Focuser(i).Status;
                    else
                        status.Focuser{i}='disconnected';
                    end
                catch
                    status.Focuser{i}='unreachable';
                end
            end
            %
            status.Switch=cell(1,numel(U.PowerSwitch));
            for i=1:numel(U.PowerSwitch)
                if ~isempty(U.PowerSwitch{i}.Name)
                    status.Switch{i}='connected';
                else
                    status.Switch{i}='unreachable';
                end
             end
        end


        function power=get.MountPower(U)
            try
                power=...
                    U.PowerSwitch{U.MountPowerUnit}.Outputs(U.MountPowerOutput);
            catch
                power=false;
            end
        end


        function set.MountPower(U,power)
            U.PowerSwitch{U.MountPowerUnit}.Outputs(U.MountPowerOutput)=power;
        end


        function Power=get.CameraPower(U)
            numcam=numel(U.Camera);
            Power=false(1,numcam);
            Switches=unique(U.CameraPowerUnit);
            for i=1:numel(Switches)
                onThisSwitch=U.CameraPowerUnit==Switches(i);
                try
                    outputs=...
                        U.PowerSwitch{Switches(i)}.Outputs;
                    Power(onThisSwitch)=...
                         outputs(U.CameraPowerOutput(onThisSwitch));
                catch
                    Power(onThisSwitch)=false;
                end
            end
        end
        
        function set.CameraPower(U,power)
            numcam=numel(U.Camera);
            for i=1:min(numcam,numel(power))
                IPswitch=U.PowerSwitch{U.CameraPowerUnit(i)};
                IPoutput=U.CameraPowerOutput(i);
                IPswitch.Outputs(IPoutput)=power(i);
            end
        end
        
        
        function T=get.Temperature(U)
            N=numel(U.PowerSwitch);
            T=NaN(1,N);
            for i=1:N
                T(i)= U.PowerSwitch{i}.Sensors.TemperatureSensors(1)';
            end
        end
    end

end
