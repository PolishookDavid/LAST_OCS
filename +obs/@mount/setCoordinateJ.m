function setCoordinateJ(MountObj, NewRA,NewDec,RA,Dec, InputEquinox)
    % like setCoordinate, but for input coordinates in arbitrary equinox.
    % Default is coordinates in J2000.0
    %
    % Example: If coordinate of star at field center is NewRA, NewDec (deg)
    %          setCoordinateJ(MountObj, NewRA, NewDec)

    arguments
        MountObj
        NewRA
        NewDec
        RA          = [];
        Dec         = [];
        InputEquinox     = 'J2000.0';
    end
    
    RAD = 180./pi;
    
    % convert coordinates from InputEquinox to Jdate
    JD = celestial.time.julday;
    [NewRA_t,NewDec_t] = celestial.coo.convert_coo(NewRA./RAD, NewDec./RAD, InputEquinox, 'tdate' , JD);
    
    if isempty(RA) && isempty(Dec)
        MountObj.setCoordinate(NewRA_t.*RAD, NewDec_t.*RAD);
    else
        [RA_t,Dec_t] = celestial.coo.convert_coo(RA./RAD, Dec./RAD, InputEquinox, 'tdate' , JD);
        MountObj.setCoordinate(NewRA_t.*RAD, NewDec_t.*RAD, RA_t.*RAD, Dec_t.*RAD);
    end
    
end
