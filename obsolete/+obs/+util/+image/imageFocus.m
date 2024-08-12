function FocVal=imageFocus(Image,ImageHalfSize,SigmaVec,PixScale,SeveralPositions)
% Compute a quality value of the focus of the image according to various
%   control parameters (for use essentially of unitCS.focusLoop)
%
% Code derived from what was in focus_loop_new()
%
% This function is probably obsoleted by the new imUtil.psf.fwhm_fromBank,
%  called directly by focusLoop.
%
% Output: FocVal, scalar or array of same length of SeveralPositions
%
% Author: Enrico, based on Eran's code
    if ~exist('SigmaVec','var')
        SigmaVec=[0.1, logspace(0,1,25)].';
    end
    if ~exist('PixScale','var')
        PixScale=1.25;
    end
    if ~exist('SeveralPositions','var')
        SeveralPositions=[];
    end

    if ~exist('ImageHalfSize','var') || isempty(ImageHalfSize)
        Image = single(Image);
    else
        Image = single(imUtil.image.trim(Image,ImageHalfSize.*ones(1,2),'center'));
    end
    
    % filter image with filter bank of gaussians with variable width
    SN = imUtil.filter.filter2_snBank(Image,[],[],@imUtil.kernel2.gauss,SigmaVec);
    [BW,Pos,MaxIsn]=imUtil.image.local_maxima(SN,1,5);
    % remove sharp objects
    Pos = Pos(Pos(:,4)~=1,:);
    
    if isempty(SeveralPositions)
        if isempty(Pos)
            FocVal = NaN;
        else
            % instead one can check if the SN improves...
            FocVal = 2.35.*PixScale.*SigmaVec(mode(Pos(Pos(:,3)>50,4),'all'));
        end
    else
        % measure focus at several positions
        Nsp = numel(SeveralPositions);
        FocVal=nan(1,Nsp);
        MaxRad = 1000;
        for Isp=1:1:Nsp
            DistPos = tools.math.geometry.plane_dist(SeveralPositions(Isp,1),...
                                                     SeveralPositions(Isp,2),...
                                                     Pos(:,1),Pos(:,2));
            Flag = DistPos<MaxRad;
            if isempty(Pos(Flag,:))
                FocVal(1) = NaN;
            else
                FocVal(Isp) = 2.35.*PixScale.*SigmaVec(mode(Pos(Pos(Flag,3)>50,4),'all'));
            end
        end
    end
