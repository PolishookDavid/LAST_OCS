function varargout=tryAndCatch(Fun,FunPar,varargin)
% try and catch generic function and messaging
% Package: LAST_OCS/+obs/+util 
% Description: This function will attempt to execute a function inside a
%              try catch block. If failed, will wait, and try again.
%              If failed will return empty, and send an error message.
% Input  : - A function handle for execution.
%          - A cell array of additional input arguments to pass to the
%            function handle.
%          * Arbitrary number of pairs of arguments: ...,keyword,value,...
%            Possible keywords are:
%            'Message' - The error message to print/save if a problem was
%                   encountered.
%                   Default is ''.
%            'Pause' - Pause time [s] after failure. Default is 1.
%            'MsgIsErr' - If true, then will quit with error if failed.
%                   Default is false.
%            'NoutArg' - Number of output arguments by function.
%                   Default is 1.
%            'updateObj' - Optional object name (e.g., MountObj) that will
%                   be update in case of sucess or error.
%                   If empty, ignore.
%                   Default is empty.
%            'updateProp' - Property in the 'updateObj' that will be
%                   updated with the error message.
%                   Default is ''.
%            'updatePropRC' - Property in the 'updateObj' that will be
%                   updated with the sucess of the execution (true/false).
%                   Default is ''.
% Output : - Output arguments by the function.
% Example: [a,b]=obs.util.tryAndCatch(@myFun,{},'Message','Error message','NoutArg',2)
% Example: obs.util.tryAndCatch(@MountObj.RA, {RA}, 'NoutArg',0, 'Message','Error message', 'updateObj','MountObj', 'updateProp','LastError', 'updatePropRC','LastRC')


InPar = inputParser;
addOptional(InPar,'Message','');
addOptional(InPar,'Pause',1);
addOptional(InPar,'MsgIsErr',false);
addOptional(InPar,'NoutArg',1);
addOptional(InPar,'Verbose',false);


addOptional(InPar,'updateObj',[]);  % M (handle object!!!)
addOptional(InPar,'updateProp',''); % 'lastError'
addOptional(InPar,'updatePropRC',[]);  %'lastRC'

parse(InPar,varargin{:});
InPar = InPar.Results;



try
    [varargout{1:InPar.NoutArg}]=Fun(FunPar{:});
    
    % update RC
    if ~isempty(InPar.updateObj) && ~isempty(InPar.updatePropRC) && ~isempty(varargout{1:InPar.NoutArg})
        InPar.updateObj.(InPar.updatePropRC) = true;
    end
    
catch
    % failed 1st time
    
    pause(InPar.Pause);
    
    % add an error to the Log ?
    
    try
        [varargout{1:InPar.NoutArg}]=Fun(FunPar{:});
        
        % update RC
        if ~isempty(InPar.updateObj) && ~isempty(InPar.updatePropRC)
            InPar.updateObj.(InPar.updatePropRC) = true;
        end
        
    catch
        % failed 2nd time
        
        if InPar.MsgIsErr
            error(InPar.Message);
        else
            warning(InPar.Message);
        end
        
        % update Obj/Prop
        if ~isempty(InPar.updateObj) && ~isempty(InPar.updateProp)
            InPar.updateObj.(InPar.updateProp) = InPar.Message;
        end
        
        if ~isempty(InPar.updateObj) && ~isempty(InPar.updatePropRC)
            InPar.updateObj.(InPar.updatePropRC) = false;
        end
        
        % add error to the log
        
    end
    
end
    
            
    
    
    