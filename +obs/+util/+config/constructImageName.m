function FileName = constructImageName(ObservatoryNode, MountGeoName, CamGeoName, ImageDateTime, Filter, CCDnum, ImType, ImageFormat)

% Construct a name for the image file. Includes:
% - observatory node (i.e. a group of telescopes)
% - mount location in the node (a number)
% - camera location on the mount (e/w for East or West)
% - date and time (YYYYMMDD.HHMMSS.FFF)
% - filter (e.g. clear, V, B, ...)
% - ccd number on the camera
% - image type (e.g. science, dark, bias, flat, mask, cat)
% - image format (e.g. fits)
% Wrote David Polishook June 2020

% SHOULD CCDnum BE STRING OR DOUBLE ??? DP

FileName = sprintf('LAST.%s.%s.%s_%s_%s_%s_%s.%s', ...
                   ObservatoryNode, MountGeoName, CamGeoName, ImageDateTime, Filter, CCDnum, ImType, ImageFormat);
   
               
end