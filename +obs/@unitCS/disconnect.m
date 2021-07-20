function UnitObj=disconnect(UnitObj)
    % disconnect all objects of the Unit

    for I=UnitObj.LocalTelescopes
        UnitObj.Camera{I}.disconnect;
        UnitObj.Focuser{I}.disconnect;
    end
    UnitObj.Mount.disconnect;
end
