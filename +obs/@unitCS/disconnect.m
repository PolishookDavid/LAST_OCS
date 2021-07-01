function UnitObj=disconnect(UnitObj)
    % disconnect all objects of the Unit

    for I=1:UnitObj.NumberLocalTelescopes
        UnitObj.Camera{I}.disconnect;
        UnitObj.Focuser{I}.disconnect;
    end
    UnitObj.Mount.disconnect;
end
