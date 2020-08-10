function plot_distortion_map(MountHA,MountDec,AstHA,AstDec)
%




InPar = inputParser;
addOptional(InPar,'ValidRangeHA',[-120 120]);  
addOptional(InPar,'ValidRangeDec',[-60 90]);  

addOptional(InPar,'Verbose',true);
addOptional(InPar,'Plot',true);
parse(InPar,varargin{:});
InPar = InPar.Results;



FlagValid = MountHA>InPar.ValidRangeHA(1) & MountHA<InPar.ValidRangeHA(2) & ...
            MountDec>InPar.ValidRangeDec(1) & MountDec<InPar.ValidRangeHA(2) & ...