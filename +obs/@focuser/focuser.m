% Focuser superclass
% Package: +obs
% Description: operate focuser drivers.
%              Currently can work with Celestron's focusers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
classdef focuser < inst.device
            
    properties (SetAccess=public, GetAccess=private)
        FocuserUniqueName = NaN;
    end
        
    properties (Hidden=true)
        LogFile;
        PromptMirrorLock logical    = true;  % Prompt the user to check if mirror is locked
        PhysicalAddress                      % focuser address (e.g. pci-bridge-usb)
    end
    
    properties (Hidden=true, GetAccess=public, SetAccess=private, Transient)
        Ready=struct('flag',true,'reason',''); % if and why the focuser can be operated
    end

    
    % constructor and destructor
    methods
        function Focuser=focuser(id)
            % Focuser constructor
            % Input  : the .Id label
            % Output : - A focuser object
            if exist('id','var')
                Focuser.Id=id;
            end
            % load configuration
            Focuser.loadConfig(Focuser.configFileName('createsuper'))
            
            if Focuser.PromptMirrorLock
                fprintf('Release the mirror of the telescope using the two black knobs at the bottom!!!\n');
                Answer = input('Is the mirror unlocked? [y/n]\n', 's');
                switch lower(Answer)
                    case 'y'
                        % continue
                        Cont = true;
                    otherwise
                        fprintf('Will not continue when mirror is locked\n');
                        Cont = false;
                        delete(Focuser);
                end
            else
                Cont = true;
            end
            
            if Cont
               % boh...
            end
             
        end
        
        function delete(Focuser)
        end

    end
    
    % getter for isReady
    methods
        function r=get.Ready(F)
            r=struct('flag',false,'reason',F.Status);
            switch r.reason
                case 'idle'
                    r.flag=true;
            end
        end
    end
end
