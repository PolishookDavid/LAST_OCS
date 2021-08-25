function pointAndClickMove(UnitObj,telescope)
    % Interactively moving the mount by clicking a position on image
    % TODO!
    % NEED TO CHECK IF DS9 IS OPEN AND THE RELEVANT FRAME IS DISPLAYED!
    % WHAT TO DO FOR REMOTE DS9 XWINDOW? CAN WE AVOID THE EXPENSIVE
    % ds9.read2sim?
    RAD = 180./pi;
    ARCSEC_IN_DEG = 3600;

    % in the future read from the config file
    PixScale = 1.25;
    RAMotionSign  = -1;
    DecMotionSign = -1;

    fprintf('Press left click to select a position in image\n')
    %[X,Y,V,Key] = ds9.getcoo(1,'mouse');
    [X,Y,V,Key] = ds9.ginput('image',1,'mouse');

    S = ds9.read2sim;
    CenterYX = size(S.Im).*0.5;

    % calculate shift relative to image center
    DY = CenterYX(1) - Y;
    DX = CenterYX(2) - X;

    RA  = UnitObj.Mount.RA;
    Dec = UnitObj.Mount.Dec;

    % convert to J2000.0
    [RA,Dec] = celestial.coo.convert_coo(RA./RAD,Dec./RAD,'tdate','J2000.0');
    RA  = RA.*RAD;
    Dec = Dec.*RAD;
    RA  = RA  + RAMotionSign.* DX.*PixScale./(ARCSEC_IN_DEG.*cosd(Dec));
    Dec = Dec + DecMotionSign.*DY.*PixScale./ARCSEC_IN_DEG;

    UnitObj.Mount.goToTarget(RA,Dec,'InCooType','J2000.0');

end
