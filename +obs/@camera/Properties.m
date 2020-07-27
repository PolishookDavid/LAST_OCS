function Properties(CameraObj)
% Print all properties, public and hidden, on the screen

% THIS IS NOT READY YET. DP July 2020

        CameraObj.CamStatus

        CameraObj.LastImageName
        CameraObj.LastImage

        CameraObj.ExpTime
        CameraObj.Gain
        CameraObj.binning

        CameraObj.CoolingStatus
        CameraObj.Temperature
        CameraObj.CoolingPower

        CameraObj.IsConnected
        CameraObj.SaveOnDisk
        CameraObj.Display

        CameraObj.CCDnum
        CameraObj.Filter
        CameraObj.ImType
        CameraObj.Object
        CameraObj.LogFile

        CameraObj.CamType
        CameraObj.CamModel
        CameraObj.CamUniqueName
        CameraObj.CamGeoName
        CameraObj.cameranum
        
        CameraObj.ReadMode
        CameraObj.Offset
        
        CameraObj.ROI % beware - SDK does not provide a getter for it, go figure
    
%         time_start=[];
%         time_end=[];
    
        CameraObj.physical_size
        CameraObj.effective_area
        CameraObj.overscan_area
        CameraObj.readModesList
        CameraObj.lastExpTime
        CameraObj.progressive_frame % image of a sequence already available
        CameraObj.time_start_delta % uncertainty, after-before calling exposure start
    
    % settings which have not been prescribed by the API,
    % but for which I have already made the code
        CameraObj.color
        CameraObj.bitDepth
    
        CameraObj.CamHn      % Handle to camera driver class
        CameraObj.MouHn      % Handle to mount driver class
        CameraObj.FocHn      % Handle to focuser driver class
        CameraObj.ReadoutTimer
        CameraObj.lastError
        CameraObj.ImageFormat
        CameraObj.LastImageSearialNum
        CameraObj.Verbose


end
