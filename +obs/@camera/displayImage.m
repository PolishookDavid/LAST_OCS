function displayImage(CameraObj,Display,DisplayZoom,DivideByFlat)
    % display LastImage in ds9 or matlab figure
    % Input : - A obs.camera object
    %         - Display window: 'ds9' | 'matlab' | ''.
    %           If empty then do not display the image.
    %           Default is to use the CameraObj.Display property.
    %         - Display Zoom for 'ds9'.
    %           Default is to use the CameraObj.DisplayZoom property.
    %         - A logical flag indicating if to subtract dark and
    %           divide by flat propr to display.
    %           Default is to use the CameraObj.DivideByFlat property.

    if nargin<4
        DivideByFlat = CameraObj.DivideByFlat;
        if nargin<3
            DisplayZoom = CameraObj.DisplayZoom;
            if nargin<2
                Display = CameraObj.Display;
            end
        end
    end

    % check if there is an image to display
    if ~isempty(CameraObj.LastImage)
        if ~isempty(Display)
            if DivideByFlat
                Image = CameraObj.divideByFlat(CameraObj.LastImage);
            else
                Image = CameraObj.LastImage;
            end
            % dispaly
            switch lower(Display)
                case 'ds9'
                    % Display in ds9 each camera in a different frame
                    if isempty(CameraObj.Frame)
                        Frame = CameraObj.CameraNumSDK;
                    else
                        Frame = CameraObj.Frame;
                    end
                    ds9(Image, 'frame', Frame);

                    if ~isempty(DisplayZoom)
                        ds9.zoom(DisplayZoom, DisplayZoom);
                    end


                case {'mat','matlab'}
                    % find reasonable range
                    Range = quantile(Image(:),[0.2, 0.95]);
                    imtool(Image,Range);

                case ''
                    % no display

                otherwise
                    error('Unknown Display option');
            end
        end

    else
        CameraObj.reportError('No Image to display');
%        CameraObj.LogFile.writeLog('No Image to display');
    end

end
