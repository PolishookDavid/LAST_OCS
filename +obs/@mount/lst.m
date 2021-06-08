function LST=lst(MountObj)
    % Get the Local Sidereal Time (LST) in [deg]

    RAD = 180./pi;
    % Get JD from the computer
    JD = celestial.time.julday;
    LST = celestial.time.lst(JD,MountObj.ObsLon./RAD);  % fraction of day
    LST = LST.*360;
end
