        function abort(UnitObj,state)
            % propagate the abort signal to all slaves using responders. A
            %  bit overdoing but probably necessary
            % this needs to be a method and cannot just be an augmentation
            %  of the setter of Unit.AbortActivity because we need to use
            %  inputname()
            UnitName=inputname(1);
            if ~exist('state','var') || state
                state=true;
                cstate='true';
            else
                state=false;
                cstate='false';
            end
            UnitObj.AbortActivity=state;
            for i=1:numel(UnitObj.Slave)
                if ~isempty(UnitObj.Slave(i).Responder)
                    UnitObj.Slave(i).Responder.send(sprintf('%s.AbortActivity=%s;',...
                        UnitName,cstate));
                end
            end
        end
