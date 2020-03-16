function abort(CameraObj)
   % call both stopping functions, how could we know
   % in which acquisition mode we are?
   CameraObj.CameraDriverHndl.abort;
end
