function AllFlag = isIdle(CameraObj)
    % Return true (per camera) if camera is idle           
    N = numel(CameraObj);
    AllFlag = false(1,N);
    for I=1:1:N
        switch lower(CameraObj(I).Status)
            case 'idle'
                AllFlag(I) = true;
            otherwise
                % do nothing (already false)
        end
    end            
end
