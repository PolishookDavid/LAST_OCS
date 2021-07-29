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
        else
            UnitObj.report(sprintf('new image available from camera %s\n',SourceCamera.Id))
        end
        
        % Save the image according to setting.
        if SourceCamera.SaveOnDisk
            UnitObj.saveCurImage(icam);
            SourceCamera.LastImageSaved = true;
        end
