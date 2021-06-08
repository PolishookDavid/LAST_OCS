function TR_Dec=trackingSpeedDec(MountObj)
    % Return tracking rate in Dec [deg/s]

    Rate   = MountObj.TrackingSpeed;
    TR_Dec = Rate(2);

end
