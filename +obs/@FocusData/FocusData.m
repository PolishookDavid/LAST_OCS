classdef FocusData
    % a class for holding all the data produced by unitCS.FocusTel focusing
    %  loop procedure
    properties
        Status   = '';
        BestPos  = NaN;
        BestFWHM = NaN;
        Counter  = NaN;
        ResTable = struct('FocPos',[],'FWHM',[],'Nstars',[],'FlagGood',false);    
    end
    
    methods
        % constructor, with a structure as argument to populate the fields
        %  appearing
        function F=FocusData(datastruct)
            if exist('datastruct','var') && ~isempty(datastruct) && isstruct(datastruct)
                fn=fieldnames(datastruct);
                for i=1:numel(fn)
                    try
                        F.(fn{i})=datastruct.(fn{i});
                    catch
                    end
                end
            end
        end
    end
end