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
    
    % convert coordinates from InputEquinox to Jdate
    JD = celestial.time.julday;
    ObsCoo
    [NewRA_t,NewDec_t] = celestial.coo.convert_coo(NewRA, NewDec, InputEquinox, 'tdate' , JD);
    
    if isempty(RA) && isempty(Dec)
        MountObj.setCoordinate(NewRA_t,NewDec_t);
    else
        [RA_t,Dec_t] = celestial.coo.convert_coo(RA, Dec, InputEquinox, 'tdate' , JD);
        MountObj.setCoordinate(NewRA_t,NewDec_t,RA_t,Dec_t);
    end
    
end
