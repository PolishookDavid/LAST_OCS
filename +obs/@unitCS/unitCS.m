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

    properties(GetAccess=public, SetAccess=private)
        Status char % general readiness status of the unit, derived from the status of its components
    end
        
    properties (Dependent)
        % Cameras
        ImType     = 'sci';
        Object     = '';
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
        MountDriver = 'inst.XerxesSimulated';
        FocuserDriver
        CameraDriver
    end

    methods
        % constructor, destructor and connect
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
            
            % populate mount, camera, focuser and power switches handles
            % for now always one mount (could be 0 for slave?)
            UnitObj.Mount=eval([UnitObj.MountDriver ...
                            '(''' sprintf('%d_%d',UnitObj.NodeNumber,1) ''')']);...
            N=UnitObj.NumberLocalTelescopes;
            UnitObj.Camera=cell(1,N);
            UnitObj.Focuser=cell(1,N);
            for i=1:N
                telescope_label=sprintf('%d_%d_%d',UnitObj.NodeNumber,1,i);
                UnitObj.Camera{i}=...
                    obs.camera(telescope_label);
                UnitObj.Focuser{i}=eval([UnitObj.FocuserDriver{i} ...
                                        '(''' telescope_label ''')']);
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
            % general status: idle | tracking | busy | exposing or
            %   something like that. TODO
            % check separately the status of mount, cameras, focusers and
            %  report accordingly
        end
        
    end
           
    
end
