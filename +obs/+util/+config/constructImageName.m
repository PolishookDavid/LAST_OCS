function FileName = constructImageName(ProjectName, ObservatoryNode, MountGeoName, CamGeoName, ImageDateTime, Filter, FieldID, ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, ImageFormat)

% Construct a name for the image file. Includes:
% - Project name (i.e. LAST)
% - observatory node (i.e. a group of telescopes)
% - mount location in the node (a number)
% - telescope/camera location in the node (a number)
% - date and time (YYYYMMDD.HHMMSS.FFF)
% - filter (e.g. clear, V, B, ...)
% - Field ID: any sky position identifier such as field ID, object name, ccd ID, sub-image ID
% - image type (e.g. science, dark, bias, flat, mask, cat)
% - image level: raw, proc, log, stack, coadd, , ref.
% - image sub level: normal, proper subtraction, proper coaddition, etc.)
% - image product: image, background, psf, etc...)
% - image version: 1 for raw images, mcan be larger for proc images
% - image format (e.g. fits)
% Wrote David Polishook June 2020

% SHOULD CCDnum BE STRING OR DOUBLE ??? DP

FileName = sprintf('%s.%s.%s.%s_%s_%s_%s_%s_%s.%s_%s_%s.%s', ...
                   ProjectName, ObservatoryNode, MountGeoName, CamGeoName, ImageDateTime, Filter, FieldID, ImType, ImLevel, ImSubLevel, ImProduct, ImVersion, ImageFormat);

               
               
% Old version. Changed on Dec 9. DP

% % Construct a name for the image file. Includes:
% % - observatory node (i.e. a group of telescopes)
% % - mount location in the node (a number)
% % - camera location on the mount (e/w for East or West)
% % - date and time (YYYYMMDD.HHMMSS.FFF)
% % - filter (e.g. clear, V, B, ...)
% % - ccd number on the camera
% % - image type (e.g. science, dark, bias, flat, mask, cat)
% % - image format (e.g. fits)
% % Wrote David Polishook June 2020
% 
% % SHOULD CCDnum BE STRING OR DOUBLE ??? DP
% 
% FileName = sprintf('LAST.%s.%s.%s_%s_%s_%s_%s.%s', ...
%                    ObservatoryNode, MountGeoName, CamGeoName, ImageDateTime, Filter, CCDnum, ImType, ImageFormat);
%    
               
end