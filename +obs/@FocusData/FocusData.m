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
    
end