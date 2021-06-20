% Focuser control handle class (for Celestron's focusers) 
% Package: +obs
% Description: operate focuser drivers.
%              Currently can work with Celestron's focusers
% Input  : Focuser text, e.g. 'Robot'.
% Output : A focuser class
%     By :
% Example: F = obs.focuser;
%          F = obs.focuser('Robot');    % Will skip lock-question
%
% Settings properties and methods:
%       F.Pos = 20000;        % Move the absolute value to 20000;
%       F.relPos(-100);       % Move 100 steps inword from current location.
%       F.Handle;             % Direct excess to the driver object
%
% More values to get:
%       F.Status              % Presents working status of focuser
%       F.Limits              % Presents defined limits of the focuser movement
%       F.waitFinish;         % Wait for fociser status to be Idle
%
% Author: David Polishook, Mar 2020
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
classdef focuser <obs.LAST_Handle
    
    properties (Hidden, GetAccess=public, SetAccess=private)
        IsConnected logical    = false;
    end
    
        
    properties (SetAccess=public, GetAccess=private)
        FocuserUniqueName = NaN;
    end
        
    properties (Hidden=true)
        LogFile;
        PromptMirrorLock logical    = true;  % Prompt the user to check if mirror is locked
        PhysicalAddress                      % focuser address (e.g. pci-bridge-usb)
    end
    
    properties (Hidden=true, GetAccess=public, SetAccess=private, Transient)
        FocusMotionTimer;
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
            Focuser.loadConfig(Focuser.configFileName('create'))
            
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
    
end
