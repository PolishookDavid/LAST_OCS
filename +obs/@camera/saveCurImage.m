function saveCurImage(CameraObj)
% Save last image to disk according the user's settings

% Get user definition for saving options
if (CameraObj.SaveOnDisk)

   % Get directory to save image in
   BaseDir = '/home/last/images/';
   T = celestial.time.jd2date(floor(celestial.time.julday));
   DirName = sprintf('%s%d%02d%02d',BaseDir, T(3), T(2), T(1));
   if (~exist([DirName],'dir'))
      % create dir
      mkdir(DirName);
   end
   cd(DirName);

   % Construct image name
   
   SerialNum = CameraObj.LastImageSearialNum + 1;
   ImageDate = datestr(CameraObj.CameraDriverHndl.time_start,'yyyymmdd.HHMMSS.FFF');
   if (isnan(CameraObj.MountHndl.MountType))
      MountGeoName = 0;
   else
      MountGeoName = CameraObj.MountHndl.MountGeoName;
   end
   
   LAST.0.1.e_YYYYMMDD.HHMMSS.FFF_Filter_CCDnum_ImType.fits
   
   CameraObj.LastImageName = sprintf('%07d_LAST_n0_t%s%s_%s_%s.fits', SerialNum, MountGeoName, CameraObj.CamGeoName, ImageDate, CameraObj.ImType)

   Header = CameraObj.updateHeader;
   FITS.write(single(CameraObj.CameraDriverHndl.lastImage), CameraObj.LastImageName,'Header',Header,'DataType','single');

   CameraObj.LastImageSearialNum = SerialNum;

   fprintf('%s is written\n', CameraObj.LastImageName)

end

% NOT READY YET - DP, Mar 16, 2020


end