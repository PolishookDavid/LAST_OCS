classdef pointingModel < obs.LAST_Handle
    % class for interpolation data for the mount pointing model
    properties
        PointingData (:,4) double
        InterpHa (1,1) scatteredInterpolant
        InterpDec (1,1) scatteredInterpolant
    end
    
    methods
        % constructor
        function P = pointingModel(id)
            if exist('id','var')
                P.Id=id;
            end
            P.loadConfig(P.configFileName('create'));
            if ~isempty(P.PointingData)
                % note: set a different extrapolation method if so desired
                P.InterpHa=scatteredInterpolant(P.PointingData(:,1:2),...
                                  P.PointingData(:,3),'linear','nearest');
                P.InterpDec=scatteredInterpolant(P.PointingData(:,1:2),...
                                  P.PointingData(:,4),'linear','nearest');
            end
        end
        
        % no further data methods: the interpolating functions are just
        %  called as such by obs.mount.goToTarget()
    end
end

