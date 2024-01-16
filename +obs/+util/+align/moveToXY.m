function [DRA,DDec]=moveToXY(UnitCS, FromXY, ToXY, Args)
    % Move mount such that a set of X/Y coordinates will shift to a new X/Y position.
    %   E.g., this can be used to center a star in the image center, etc.
    %   This function assumes that the camera X/Y directions are aligned
    %   with the equatorial coordinates.
    % Input  : - An obs.unitCS object.
    %          - The current [X,Y] of the object we want to move.
    %          - The target [X,Y] to which the object will move.
    %            If empty, then ImageSize./2. Default is [].
    %          * ...,key,val,...
    %            'Move' - A logical indicating if to move the mount or only
    %                   calculate the DeltaRA, DeltaDec of the move.
    %            'Scale' - Default is 1.25"/pix.
    %            'DirRA' - RA direction on image. Default is '+x'.
    %                   This default is good for all cameras.
    %            'DirDec' - Dec direction on image. Default is '+y'.
    %            'ImageSize' - Image size. Default is [6388 9600].
    % Output : - DeltaRA [deg].
    %          - DeltaDec [deg].
    % AUthor : Eran Ofek (Dec 2021)
    % Example: [DRA,DDec]=obs.util.align.moveToXY(P,[5749 5151],[]);
    
    arguments
        UnitCS obs.unitCS
        FromXY
        ToXY                  = [];  % if empty use center
        Args.Move logical     = true;
        Args.Scale            = 1.25;    % arcsec/pix
        Args.DirRA            = '+x';
        Args.DirDec           = '+y';
        Args.ImageSize        = [6388 9600];
    end
    ARCSEC_DEG = 3600;
    
    if isempty(ToXY)
        ToXY = Args.ImageSize.*0.5;
    end
    
    %UnitCS.takeExposure(Camera, Args.ExpTime, 1);
    %UnitCS.readyToExpose(Camera, true, Args.ExpTime+3);
    
    DX = FromXY(1) - ToXY(1);
    DY = FromXY(2) - ToXY(2);
    
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
   
    if Args.Move
        % actual move
        RA  = UnitCS.Mount.RA;    % mount equinox of date coo
        Dec = UnitCS.Mount.Dec;   % mount equinox of date coo
        
        UnitCS.Mount.goTo(RA+DRA, Dec+DDec, 'eq');
    end
    
end
