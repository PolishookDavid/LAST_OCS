function [DRA,DDec]=moveToXY(UnitCS, FromXY, ToXY, Args)
    %
    % Example: [DRA,DDec]=obs.util.align.moveToXY(P,[5749 5151],[]);
    
    arguments
        UnitCS obs.unitCS
        FromXY
        ToXY                  = [];  % if empty use center
        Args.Scale            = 1.25;    % arcsec/pix
        Args.DirRA            = '+x';
        Args.DirDec           = '+y';
    end
    ARCSEC_DEG = 3600;
    
    if isempty(ToXY)
        ToXY = [2300 4800]   % update
    end
    
    %UnitCS.takeExposure(Camera, Args.ExpTime, 1);
    %UnitCS.readyToExpose(Camera, true, Args.ExpTime+3);
    
    DX = FromXY(1) - ToXY(1)
    DY = FromXY(2) - ToXY(2)
    
    switch lower(Args.DirRA)
        case '+x'
            DRA = DX;
        case '-x'
            DRA = -DX;
        case '+y'
            DRA = DY;
        case '-y'
            DRA = -DY;
        otherwise
            error('Unknown DirRA option');
    end
    
    switch lower(Args.DirDec)
        case '+x'
            DDec = DX;
        case '-x'
            DDec = -DX;
        case '+y'
            DDec = DY;
        case '-y'
            DDec = -DY;
        otherwise
            error('Unknown DirRA option');
    end
    
    DRA = DRA.*Args.Scale./ARCSEC_DEG ./cosd(UnitCS.Mount.Dec);
    DDec = DDec.*Args.Scale./ARCSEC_DEG;
    
end
