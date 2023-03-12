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

classdef unitCS < obs.LAST_Handle

    properties
        PowerSwitch  cell   % handles to IP power switches units
        Mount               % handle to the mount(s) abstraction object
        MountPower logical % power of the mount, off/on
        Camera cell    % cell, handles to the camera abstraction objects
        CameraPower logical % power of the cameras off/on
        Focuser cell   % cell, handles to the focuser abstraction objects
    end

    properties(Hidden)
        % non-structured notation because of limitations of the yml configuration
        CameraPowerUnit double =[]; % switch unit controlling each camera
        CameraPowerOutput double =[]; % switch output controlling each camera
        MountPowerUnit double =[];% switch controlling mount power
        MountPowerOutput double=[]; % switch output controlling the mount
        MountNumber            = 99;  % Mount number 1..12 - 99=unknown (currently taken from Id)
    end

    properties(GetAccess=public, SetAccess=?obs.LAST_Handle)
        %these are set only when reading the configuration
        LocalTelescopes % indices of the local telescopes
        RemoteTelescopes='{}'; % evaluates to a cell, indices of the telescopes assigned to each slave
        Slave cell; % handles to SpawnedMatlad sessions
        Temperature double; % temperature reading from the IPswitch 1wire sensors
    end
    
    properties(GetAccess=public, SetAccess=?obs.LAST_Handle, Hidden)
        %these are set only when reading the configuration. Due to the
        % current yml configuration reader, the configuration can contain
        % only a string significating class names, which are then used
        % to construct the actual object handles by eval()'s
        PowerDriver % class name of the power switch driver [configuration only]
        MountDriver % class name of the mount driver [configuration only]
        FocuserDriver % class names of the focuser drivers [configuration only]
        CameraDriver  % class names of the camera drivers [configuration only]
        
    end

    methods
        % constructor, destructor
        function UnitObj=unitCS(id)
            % unit class constructor
            % Package: +obs/@unitCS
            if exist('id','var')
                if isnumeric(id)
                    id=num2str(id);
                end
                UnitObj.Id=id;
            end
            % load configuration
            UnitObj.loadConfig(UnitObj.configFileName('create'))
            % this one is read in as string and converted, because of limitations of
            %  Astropack's yml reader
            UnitObj.RemoteTelescopes=eval(UnitObj.RemoteTelescopes);
                        
            % populate mount, camera, focuser and power switches handles
            for i=1:numel(UnitObj.PowerDriver)
                UnitObj.PowerSwitch{i}=eval([UnitObj.PowerDriver{i} ...
                           '(''' sprintf('%s_%d',UnitObj.Id,i) ''')']);
            end
            
            % for now always one mount per unit (or, empty mount when absent)
            UnitObj.Mount=eval([UnitObj.MountDriver ...
                            '(''' sprintf('%s_%d',UnitObj.Id,1) ''')']);
            Nlocal=numel(UnitObj.LocalTelescopes);
            Nremote=numel(horzcat(UnitObj.RemoteTelescopes{:}));
            UnitObj.Camera=cell(1,Nlocal+Nremote);
            UnitObj.Focuser=cell(1,Nlocal+Nremote);
            
            % create camera and focuser objects for local telescopes,
            %  as well as listeners for new images
            for i=1:Nlocal
                j=UnitObj.LocalTelescopes(i);
                telescope_label=sprintf('%s_%d_%d',UnitObj.Id,1,j);
                UnitObj.Camera{j}=eval([UnitObj.CameraDriver{i} ...
                                        '(''' telescope_label ''')']);
                UnitObj.Focuser{j}=eval([UnitObj.FocuserDriver{i} ...
                                        '(''' telescope_label ''')']);
                % better listener or addlistener?
                addlistener(UnitObj.Camera{j},'LastImage','PostSet',@UnitObj.treatNewImage);
            end
            
            % create remoteClass objects for remote telescopes
            for i=horzcat(UnitObj.RemoteTelescopes{:})
               UnitObj.Camera{i}=obs.remoteClass;              
               UnitObj.Focuser{i}=obs.remoteClass;
            end
            
            % create slaves for spawned sessions running remote telescopes
            UnitObj.Slave=cell(1,numel(UnitObj.RemoteTelescopes));
            for i=1:numel(UnitObj.RemoteTelescopes)
                UnitObj.Slave{i}=obs.util.SpawnedMatlab(sprintf('%s_slave_%d',UnitObj.Id,i));
            end
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
