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

    properties
        Mount  obs.LAST_Handle    % handle to the mount(s) abstraction object
        Camera cell    % cell, handles to the camera abstraction objects
        Focuser cell   % cell, handles to the focuser abstraction objects
    end
    
    properties(GetAccess=public, SetAccess=private)
        Status char % general readiness status of the unit, derived from the status of its components
    end
        
    properties %(Dependent)
        % Cameras
        ImType     = 'sci';
        Object     = '';
    end

    properties(GetAccess=public, SetAccess=?obs.LAST_Handle)
        %these are set only when reading the configuration
        LocalTelescopes % indices of the local telescopes
        RemoteTelescopes='{}'; % evaluates to a cell, indices of the telescopes assigned to each slave
        Slave cell; % handles to SpawnedMatlad sessions
    end
    
    properties(GetAccess=public, SetAccess=?obs.LAST_Handle, Hidden)
        %these are set only when reading the configuration. Due to the
        % current yml configuration reader, the configuration can contain
        % only a string significating class names, which are then used
        % to construct the actual object handles by eval()'s
        MountDriver = 'inst.XerxesSimulated';
        FocuserDriver
        CameraDriver
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
            % for now always one mount (could be 0 for slave?)
            UnitObj.Mount=eval([UnitObj.MountDriver ...
                            '(''' sprintf('%s_%d',UnitObj.Id,1) ''')']);...
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
        end
                        
    end
    
    % setters/getters for children of the unit
    methods
        % general
        function Val=get.Status(UnitObj)
            % general status: idle | tracking | busy | exposing or
            %   something like that. TODO
            % check separately the status of mount, cameras, focusers and
            %  report accordingly
            Val='';
        end
        
    end
           
    
end
