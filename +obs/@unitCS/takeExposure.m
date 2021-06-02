function Flag=takeExposure(UnitObj,varargin)
    % takeExposure (see also obs.camera.takeExposure)
    % Input  : - A unit object.
    %          - Exposure time [s]. If provided this will override
    %            the CameraObj.ExpTime, and the CameraObj.ExpTime
    %            will be set to this value.
    %          - Number of images to obtain. Default is 1.
    %          * ...,key,val,...
    %            'WaitFinish' - default is true.
    %            'SaveMode' - default is 2.
    %            'ImType' - default is [].
    %            'Object' - default is [].
    % Example: U.takeExposure(1,1);

    % start exposure on remote cameras


    % start exposures on local cameras

    %set ImType and Object

    Flag = UnitObj.HandleCamera.takeExposure(varargin{:});

end
