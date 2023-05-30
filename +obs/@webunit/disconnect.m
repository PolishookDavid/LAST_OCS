function success=disconnect(UnitObj)
    % disconnect all objects of the Unit

    try
        for I=numel(UnitObj.Camera)
            UnitObj.Camera{I}.Connected=false;
        end
        for I=numel(UnitObj.Focuser)
            UnitObj.Focuser{I}.Connected=false;
        end
        UnitObj.Mount.Connected=false;
        
        % declare success
        UnitObj.Connected=false;
        success=true;
    catch
        success=false;
    end
end
