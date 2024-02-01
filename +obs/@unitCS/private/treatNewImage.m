function treatNewImage(UnitObj,Source,EventData)
% callback function, launched every time a local camera object sets
%  .LastImage anew. i.e. when a new image is acquired
% This callback saves the image to the disk (if camera.SaveOnDisk==true), and sets
%  UnitObj.Camera{i}.LastImageSaved

        % sanity check: treat only changes of LastImage
        if ~strcmp(Source.Name,'LastImage')
            UnitObj.reportError('image treating callback called, but not for a change of LastImage')
            return
        end

        SourceCamera=EventData.AffectedObject;
        % identify which of the cameras of the unit reported, as index
        icam=[];
        for i=1:numel(UnitObj.Camera)
            if UnitObj.Camera{i}==SourceCamera
                icam=i;
                break
            end
        end
        if isempty(icam)
            % this shouldn't happen
            UnitObj.reportError('new image available, but not from a camera of this unit!')
            return
        end
        
        % Save the image according to setting.
        if UnitObj.Camera{icam}.SaveOnDisk
            % this creates a header, and succeeds in querying a remote mount
            %  in a slave, only because we have created a Messenger and a
            %  Responder there. With only a single messenger, asynchronous
            %  commands and queries from both sides would mix up and create
            %  a mess.
            UnitObj.saveCurImage(icam);
        end
