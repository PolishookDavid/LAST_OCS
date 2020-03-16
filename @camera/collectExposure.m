function img=collectExposure(CameraObj)
   % collect the exposed frame, but only if an exposure was started!
   img = CameraObj.CameraDriverHndl.collectExposure;
   switch CameraObj.CameraDriverHndl.lastError
       case "no image to read because exposure not started"
           CameraObj.lastError = "no image to read because exposure did not start";
   end
end
