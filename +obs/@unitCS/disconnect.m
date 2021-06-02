function UnitObj=disconnect(UnitObj)
    % disconnect all objects of the Unit

    for I=1:1:numel(UnitObj.HandleCamera)
        UnitObj.HandleCamera(I).HandleFocuser.disconnect;
        UnitObj.HandleCamera(I).disconnect;
    end
    UnitObj.HandleMount.disconnect;
end
