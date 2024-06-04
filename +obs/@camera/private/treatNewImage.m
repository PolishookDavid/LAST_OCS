function treatNewImage(CameraObj,Source,EventData)
% callback function, launched every time a local camera object sets
%  .LastImage anew. i.e. when a new image is acquired
% For the moment, just a wrapper to displayImage

    % sanity check: treat only changes of LastImage
    if ~strcmp(Source.Name,'LastImage')
        CameraObj.reportError('image treating callback called, but not for a change of LastImage')
        return
    end
    
    if ~isempty(CameraObj.LastImage)
        CameraObj.report('New image available (%d/%d) from camera %s\n',...
            CameraObj.ProgressiveFrame,CameraObj.SequenceLength,...
            CameraObj.Id)
        CameraObj.displayImage;
        
        if CameraObj.LastSeqFlag
            % add image to buffer of images
            Iim = CameraObj.ProgressiveFrame;
            CameraObj.LastSeq(Iim).Image = CameraObj.LastImage;
            CameraObj.LastSeq(Iim).JD    = CameraObj.TimeStartLastImage + 1721058.5;
        end
        
        switch CameraObj.ComputeFWHM
            case {'always','last'}
                % compute FWHM each time a new image is received, if so
                % instructed
                %  call with fixed HalfSize, TBD if ever needed different.
                %  with 1000, I've measured ~1.6 sec on a LAST computer on a
                %  typical image (is that image dependent?)
                % If we knew for sure whether we are in live or still mode, we
                %  should automatically skip this if in live mode and Texp too
                %  small for it
                if strcmpi(CameraObj.ComputeFWHM,'always') || ...
                        CameraObj.ProgressiveFrame==CameraObj.SequenceLength
                    [CameraObj.LastImageFWHM, ~] = ...
                        imUtil.psf.fwhm_fromBank(CameraObj.LastImage, 'HalfSize',1000);
                    % TBD if FWHM needs to be capped at 25 as in focusTelInSlave
                end
            case {'none'}
                CameraObj.LastImageFWHM=NaN;
            otherwise
        end
    end
