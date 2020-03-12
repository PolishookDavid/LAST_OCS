classdef focuser <handle
    
    properties
        Pos=NaN;
    end
    
    properties (GetAccess=public, SetAccess=private)
        Status='unknown';
        LastPos=NaN;
    end
        
    properties (SetAccess=public, GetAccess=private)
        relPos=NaN;
    end
        
    properties (Hidden=true)
        FocuserDriverHndl = NaN;
        Port="";
    end

    % non-API-demanded properties, Enrico's judgement
    properties (Hidden=true) 
        verbose=true; % for stdin debugging
        serial_resource % the serial object corresponding to Port
    end
    
    properties (Hidden=true, GetAccess=public, SetAccess=private, Transient)
        lastError='';
        limits=[NaN,NaN];
    end

    
    methods
        % constructor and destructor
        function F=focuser(varargin)
            if (isempty(varargin))
               Answer = input('Is the mirror unlock?\n', 's');
               if (Answer == 'Yes' | Answer == 'yes' | Answer == 'YES' | Answer == 'y')
                  F.FocuserDriverHndl=inst.CelestronFocuser;
               else
                  fprintf('Release the mirror of the telescope using the two black nobs at the bottom!!!\n')
                  fclose(F);
               end
            else
               switch varargin{1}
                  case 'Robot'
                     % The robot assumes the mirror of the telescope is
                     % unlocked, thus the focuser can move.
                     F.FocuserDriverHndl=inst.CelestronFocuser;
               end
            end
            % Connecting to port in a separate method
        end
        
        function delete(F)
%            if(~isnan(F.FocuserDriverHndl))
               delete(F.FocuserDriverHndl)
%            end
        end

    end

    methods
        %getters and setters
        function focus=get.Pos(F)
            if (isnan(F.FocuserDriverHndl.Pos))
               F.lastError = "could not read focuser position. Focuser disconnected. *Connect or Check Cables*";
               fprintf('%s\n', F.lastError)
            else
               focus = F.FocuserDriverHndl.Pos;
               switch F.FocuserDriverHndl.lastError
                  case "could not read focuser position"
                      F.lastError = "could not read focuser position";
               end
            end
        end

        function set.Pos(F,focus)
            F.LastPos = F.FocuserDriverHndl.LastPos;
            F.FocuserDriverHndl.Pos = focus;
            switch F.FocuserDriverHndl.lastError
                case "set new focus position failed"
                    F.lastError = "set new focus position failed";
                case "Focuser commanded to move out of range!"
                    F.lastError = "Focuser commanded to move out of range!";
            end            
        end
        
        function set.relPos(F,incr)
            F.FocuserDriverHndl.relPos(incr)
            switch F.FocuserDriverHndl.lastError
                case "set new focus position failed"
                    F.lastError = "set new focus position failed";
                case "Focuser commanded to move out of range!"
                    F.lastError = "Focuser commanded to move out of range!";
            end            
             % (don't use F.Pos=F.Pos+incr, it will fail, likely for access
             %  issues)
        end
        
        function focus=get.LastPos(F)
            focus = F.FocuserDriverHndl.LastPos;
            switch F.FocuserDriverHndl.lastError
                case "could not read focuser position"
                    F.lastError = "could not read focuser position";
            end
        end

        function limits=get.limits(F)
            limits = F.FocuserDriverHndl.limits;
        end
        
        function s=get.Status(F)
            s = F.FocuserDriverHndl.Status;
            switch F.FocuserDriverHndl.lastError
                case "could not get status, communication problem?"
                    F.lastError = "could not get status, communication problem?";
            end            
            % desired would be idle/moving, but there is no firmware call
            %  for that. Moving can be determined by looking at position
            %  changes? What if the focuser is stuck? what if motion has
            %  been aborted?
            % Note - the focuser response can be erratic, maybe because of
            %  poor cables, more likely because of EMI or poor engineering
            %  of the USB/serial communication module 
            %  - I've seen the focuser start moving several
            %  seconds after commanded, i.e. - this complicates guessing the
            %  status
        end
        
    end
    
end
