% unit control system handle class
% Package: +obs/@unit
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
        Mount cell     % handle to the mount(s) abstraction object
        Camera cell    % cell, handles to the camera abstraction objects
        Focuser cell   % cell, handles to the focuser abstraction objects
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
    end

    properties(GetAccess=public, SetAccess=private,Description='api')
        Temperature double; % temperature reading from the IPswitch 1wire sensors
        Status struct; % structure holding the status of all components
    end


    methods
        % constructor, destructor
        function UnitObj=webunit(Locator)
            % identify the unit by locator
            if exist('Locator','var') 
                if isa(Locator,'obs.api.Locator')
                    id = Locator.Canonical;
                else
                    id = Locator;
                end
            else
                id=''; % will cause error below
            end
            UnitObj.Id=id;
            % fill initial status of untyped .Connected
            UnitObj.Connected=false;
            % load configuration
            UnitObj.loadConfig(UnitObj.configFileName('create'))
            % this one is read in as string and converted, because of limitations of
            %  Astropack's yml reader
%             UnitObj.RemoteTelescopes=eval(UnitObj.RemoteTelescopes);
%                         
             % Populate mount, camera, focuser and power switches handles
             % NB: it would be sensible and elegant to construct locators
             %     using the relevant arguments of the constructor, e.g.
             %
             %  obs.api.Locator('ProjectName',UnitObj.ProjectName,...
             %                  'NodeId',UnitObj.NodeId,...
             %                  'MountId',UnitObj.MountId,'EquipType','Mount');
             %
             % but parsing of the arguments is yet imperfect. Thus, for the
             %  time being I construct strings, which is less elegant and
             %  more fragile
             
             % regenerate (in case passed as string) the full locator of
             % the unit
             L=obs.api.Locator('Location',id);
             % switches:
             sw=sprintf('%s.%d.psw%d', L.ProjectName, L.NodeId, L.MountId);
             UnitObj.PowerSwitch={
                 obs.api.Locator('Location',[sw 'e']), ...
                 obs.api.Locator('Location',[sw 'w'])};
%             % for now always one mount per unit (or, empty mount when absent)
%             UnitObj.Mount=
%             Nlocal=numel(UnitObj.LocalTelescopes);
%             Nremote=numel(horzcat(UnitObj.RemoteTelescopes{:}));
%             UnitObj.Camera=cell(1,Nlocal+Nremote);
%             UnitObj.Focuser=cell(1,Nlocal+Nremote);
%             
%             % create camera and focuser objects for local telescopes,
%             %  as well as listeners for new images
%             for i=1:Nlocal
%                 j=UnitObj.LocalTelescopes(i);
%                 telescope_label=sprintf('%s_%d_%d',UnitObj.Id,1,j);
%                 UnitObj.Camera{j}=eval([UnitObj.CameraDriver{i} ...
%                                         '(''' telescope_label ''')']);
%                 UnitObj.Focuser{j}=eval([UnitObj.FocuserDriver{i} ...
%                                         '(''' telescope_label ''')']);
%                 % better listener or addlistener?
%                 addlistener(UnitObj.Camera{j},'LastImage','PostSet',@UnitObj.treatNewImage);
%             end
%             
%             % create remoteClass objects for remote telescopes
%             for i=horzcat(UnitObj.RemoteTelescopes{:})
%                UnitObj.Camera{i}=obs.remoteClass;              
%                UnitObj.Focuser{i}=obs.remoteClass;
%             end
            
        end
        

        function delete(UnitObj)
            % delete unit object and related sub objects
% Be careful. Since the resources for each child are in fact unique (fixed
%  udp port numbers, fixed switch, focuser, mount), it can very well
%  happen that the destructor of an old object is called just after
%  a new one is created, causing hardware to be turned off immediately
%  after it is turned on, if the specific delete() includes that.
            for i=1:numel(UnitObj.Slave)
                delete(UnitObj.Slave{i})
            end
            delete(UnitObj.Mount);
            for i=1:numel(UnitObj.Camera)
                delete(UnitObj.Camera{i});
            end
            for i=1:numel(UnitObj.Focuser)
                delete(UnitObj.Focuser{i});
            end
            for i=1:numel(UnitObj.PowerSwitch)
                delete(UnitObj.PowerSwitch{i});
            end
        end
                        
    end
    
    % setters/getters
    methods
        function power=get.MountPower(UnitObj)
            try
                power=...
                    UnitObj.PowerSwitch{UnitObj.MountPowerUnit}.classCommand('Outputs(%d);',...
                                                UnitObj.MountPowerOutput);
            catch
                power=false;
            end
        end
        
        function set.MountPower(UnitObj,power)
            UnitObj.PowerSwitch{UnitObj.MountPowerUnit}.classCommand('Outputs(%d)=%d;',...
                                UnitObj.MountPowerOutput,power);
        end
        
        function Power=get.CameraPower(UnitObj)
            numcam=numel(UnitObj.Camera);
            Power=false(1,numcam);
            Switches=unique(UnitObj.CameraPowerUnit);
            for i=1:numel(Switches)
                onThisSwitch=UnitObj.CameraPowerUnit==Switches(i);
                try
                    outputs=...
                        UnitObj.PowerSwitch{Switches(i)}.classCommand('Outputs;');
                    Power(onThisSwitch)=...
                         outputs(UnitObj.CameraPowerOutput(onThisSwitch));
                catch
                    Power(onThisSwitch)=false;
                end
            end
        end
        
        function set.CameraPower(UnitObj,power)
            numcam=numel(UnitObj.Camera);
            for i=1:min(numcam,numel(power))
                IPswitch=UnitObj.PowerSwitch{UnitObj.CameraPowerUnit(i)};
                IPoutput=UnitObj.CameraPowerOutput(i);
                IPswitch.classCommand('OutputN(%d,%d);',IPoutput,power(i));
            end
        end
        
        function Result = get.MountNumber(UnitObj)
            % getter for MountNumber
            % currently taken from 'Id' property, which is fragile,
            %  in anticipation of a better handling
           
            Result = sscanf(UnitObj.Id,'%d');
            if isempty(Result)
                Result = 99;
            end
             
        end
        
        function T=get.Temperature(UnitObj)
            N=numel(UnitObj.PowerSwitch);
            T=NaN(1,N);
            for i=1:N
                T(i)= UnitObj.PowerSwitch{i}.classCommand('Sensors.TemperatureSensors(1)');
            end
        end
    end

end
