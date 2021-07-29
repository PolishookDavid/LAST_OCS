function treatNewImage(CameraObj,Source,EventData)
% callback function, lanunched every time a local camera object sets
%  .LastImage anew. i.e. when a new image is acquired
% For the moment, just a wrapper to displayImage

    % sanity check: treat only changes of LastImage
    if ~strcmp(Source.Name,'LastImage')
        CameraObj.reportError('image treating callback called, but not for a change of LastImage')
        return
    end
    
    CameraObj.report(sprintf('New image available from camera %s\n',CameraObj.Id))
    CameraObj.displayImage;
