function callbackSaveAndDisplay(CameraObj, ~, ~)
    % A callback function: if the camera is idle for more? than stop time,
    % save and display image
    % Input  : - Camera object.

    if numel(CameraObj)>1
        error('callbackSaveAndDisplay works on a single element camera object');
    end

    % This function may work in two manners:
    % 1. Check for idle status - however, this is problematic when
    % taking sequence of images.
    % 2. wait for LastImage to be non empty and LastImageSaved to
    % be false.

    %size(CameraObj.LastImage)
    if strcmp(CameraObj.Status,'idle') || CameraObj.SaveWhenIdle

        % camera is ready
        % Stop timer
        if ~isempty(CameraObj.ReadoutTimer)
            stop(CameraObj.ReadoutTimer);
        end

        % Save the image according to setting.
        if (CameraObj.SaveOnDisk)
            CameraObj.saveCurImage;
        end
        CameraObj.LastImageSaved = true;

        % Display the image according to setting.
        if (CameraObj.Display)
            CameraObj.displayImage;
        end
    end
end
