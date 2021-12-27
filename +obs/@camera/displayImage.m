function displayImage(CameraObj,Display,DisplayZoom,DivideByFlat)
    % *** Mastrolindo status: Ok but ds9 part uncapable of receiving simultaneous
    %                     frames, and in need of some finer parameter
    %                     passing
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
                Image = CameraObj.divideByFlat;
            else
                Image = CameraObj.LastImage;
            end
            % display
            switch lower(Display)
                case 'ds9'
                    % Display in ds9 each camera in a different frame
                    if isempty(CameraObj.Frame)
                        Frame = CameraObj.CameraNumber;
                    else
                        Frame = CameraObj.Frame;
                    end
                    try
                        % wrap in try-catch, because ds9 (xpaset) CAN
                        %  fail, and if this is called by a timer callback
                        %  an error which disarms the timer causes
                        %  more havoc
                        ds9(Image, Frame); 
                        if ~isempty(DisplayZoom)
                            ds9.zoom(DisplayZoom, DisplayZoom);
                        end
                    catch
                        CameraObj.reportError('error calling ds9 for display')
                    end
                case {'mat','matlab'}
                    % find reasonable range
                    Range = quantile(Image(:),[0.2, 0.95]);
                    % imtool is very slow, and opens every new image in a
                    %  new window. There is much room for improvement
                    imtool(Image,Range);
                case ''
                    % no display
                otherwise
                    error('Unknown Display option');
            end
        end
    else
        CameraObj.reportError('No Image to display');
%        CameraObj.LogFile.write('No Image to display');
    end

end
