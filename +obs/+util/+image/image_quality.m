function Result=image_quality(Image,varargin)
% Mesaure the image quality using variety of methods
% Input  : - An image in matrix format
%          * ...,key,val,...
%            
% Example: Result=obs.util.tools.image_quality(Image)


InPar = inputParser;
addOptional(InPar,'Method','filterBankGrid');
addOptional(InPar,'BlockSize',[1024 1024]);
addOptional(InPar,'SigmaVec',[0.1, logspace(0,1,25)].');
addOptional(InPar,'PixScale',1.25);  % "/pix
addOptional(InPar,'Verbose',true);
addOptional(InPar,'Plot',true);
parse(InPar,varargin{:});
InPar = InPar.Results;


Image = single(Image);

switch lower(InPar.Method)
    case 'filterbank'
        % filter image with filter bandk of gaussians with variable width
        SN = imUtil.filter.filter2_snBank(Image,[],[],@imUtil.kernel2.gauss,InPar.SigmaVec);
        [BW,Pos,MaxIsn]=imUtil.image.local_maxima(SN,1,5);

        % remove sharp objects
        Pos = Pos(Pos(:,4)~=1,:);
        if isempty(Pos)
            FWHM = NaN;
        else
            % instead one can check if the SN improves...
            if isempty(Pos(Pos(:,3)>50,4))
                FWHM = NaN;
            else
                FWHM = 2.35.*InPar.PixScale.*InPar.SigmaVec(mode(Pos(Pos(:,3)>50,4),'all'));
            end
        end
        
        Result.FWHM = FWHM;
        
    case 'filterbankgrid'
        
        [Sub,ListEdge,ListCenter] = imUtil.partition.image_partitioning(Image,InPar.BlockSize);
        Nsub = numel(Sub);
        FWHM = nan(size(Sub));
        for Isub=1:1:Nsub
            
            SN = imUtil.filter.filter2_snBank(Sub(Isub).Im,[],[],@imUtil.kernel2.gauss,InPar.SigmaVec);
            [BW,Pos,MaxIsn]=imUtil.image.local_maxima(SN,1,5);

            % remove sharp objects
            Pos = Pos(Pos(:,4)~=1,:);
            if isempty(Pos)
                FWHM(Isub) = NaN;
            else
                % instead one can check if the SN improves...
                if isempty(Pos(Pos(:,3)>50,4))
                    FWHM(Isub) = NaN;
                else
                    FWHM(Isub) = 2.35.*InPar.PixScale.*InPar.SigmaVec(mode(Pos(Pos(:,3)>50,4),'all'));
                end
            end
        end
        Result.FWHM = FWHM;
    otherwise
        error('Unknown Method option');
end


