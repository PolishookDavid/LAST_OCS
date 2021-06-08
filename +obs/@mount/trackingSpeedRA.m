function TR_RA=trackingSpeedRA(MountObj)
    % Return tracking rate in RA [deg/s]

    Rate  = MountObj.TrackingSpeed;
    TR_RA = Rate(1);

end
