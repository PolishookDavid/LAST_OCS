function [OperableComponents,ComponentStatus,FailureReasons]=...
               fullStatus(Unit,shortcut)
% get the full status of the unit components, and determine if and which
%   telescopes are ready to be operated
%
% Input argument: 
%   - shortcut (boolean). If true, the full status is not
%             checked, if a critical component is not operable.
%             e.g. if the mount is in fault, cameras and focusers are not
%             checked; if one focuser is in fault, the corresponding camera
%             is not checked. This in order to save querying time. In that
%             case, the status information reported will be incomplete
% Output:
%   - OperableComponents: structure with fields .Mount, .Telescope.
%                         field values are booleans. .Mount can be false if
%                         some camera is exposing. Telescope can be false
%                         if either the camera is not ready or the focuser
%                         is not
%   - Component status: structure with the status string of all relevant
%                       components (mount, slaves, camera, focusers). Note
%                       that in addition to the regular status reported by
%                       the drivers, an additional status may be 'poweroff'
%   - FailureReasons: a cell of messages explaining what is wrong
%
% Note: operative logic is involved. For example, telescopes can be
%       Operable only if the mount is tracking, but the mount itself is
%       operable also if 'idle' or 'disabled'; conversely, the mount is not
%       Operable if cameras are 'exposing', but is operable if cameras
%       are in another status
%
% Author: Enrico Segre, September 2023
%
%  ref: see also Eran's .readyToExpose method, which has a different scope
%       and is perhaps not as optimized

    if nargin==1
        shortcut=false;
    end
    % initial values before the detailed check
    % we silently assume that the unit is sanely configured, i.e. there is
    % one slave per camera and focuser
    Ntel=numel(Unit.Slave);
    OperableComponents=struct('Mount',false,'Telescope',false(1,Ntel));
    ComponentStatus=struct('Mount','','Slave',[],'Camera',[],'Focuser',[]);
    ComponentStatus.Slave=cell(1,Ntel);
    ComponentStatus.Camera=cell(1,Ntel);
    ComponentStatus.Focuser=cell(1,Ntel);
    FailureReasons={};
    
    mp=Unit.MountPower;
    if isempty(mp) || mp
        % check the mount even if the power switch didn't respond
        r=Unit.Mount.Ready;
        OperableComponents.Mount=r.flag; % may be turned false later if cameras are exposing
        ComponentStatus.Mount=r.reason;
        if shortcut && ~f.flag
            return
        end
    else
        ComponentStatus.Mount='poweroff';
        FailureReasons{numel(FailureReasons)+1}='mount is powered off';
        if shortcut
            return
        end
    end
    
    % check that slaves are alive
    ss=cell(1,Ntel);
    for i=1:Ntel
        ss{i}=Unit.Slave{i}.Status;
        if ~strcmp(ss{i},'alive')
            ComponentStatus.Slave{i}=ss{i};
            FailureReasons{numel(FailureReasons)+1}=...
                sprintf('slave %d is %s',i,ss{i});
        end
    end
    
    cp=Unit.CameraPower; % this could be shortcircuited if slaves are not alive
    for i=1:Ntel
        if isempty(cp) || cp(i)
            % also here, a non responding switch is not a reason not to try
            %  further
            if strcmp(ss{i},'alive')
                % query camera
                rc=Unit.Camera{i}.classCommand('Ready');
                ComponentStatus.Camera{i}=rc.reason;
                if ~rc.flag
                    FailureReasons{numel(FailureReasons)+1}=...
                        sprintf('camera %d is %s',i,rc.reason);
                end
                if strcmp(rc.reason,'exposing')
                   OperableComponents.Mount=false;
                end
                % query focuser
                rf=Unit.Focuser{i}.classCommand('Ready');
                ComponentStatus.Focuser{i}=rf.reason;
                if ~rf.flag
                    FailureReasons{numel(FailureReasons)+1}=...
                        sprintf('focuser %d is %s',i,rf.reason);
                end
            end
        else
            ComponentStatus.Camera{i}='poweroff';
            FailureReasons{numel(FailureReasons)+1}=...
                sprintf('camera %d is powered off',i);
        end
    end
    
    