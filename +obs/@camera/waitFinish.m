function Flag = waitFinish(CameraObj)
    % wait until all camera ended exposing, readout, and writing image and returned to idle mode

    WaitTime = 0.01;
    Flag = false;

    if CameraObj(1).Verbose
        fprintf('Wait for idle camera\n');
    end

    N = numel(CameraObj);

    StopWaiting(1,N) = false;
    while ~all(StopWaiting)

        pause(WaitTime);
        for I=1:1:N
            switch lower(CameraObj(I).Status)
                case {'exposing','reading'}
                    % do nothing - continue waiting
                case 'idle'
                    StopWaiting(I) = true;
                otherwise
                    StopWaiting(I) = true;
                    if CameraObj(I).Verbose
                        warning('waitFinish encounter an illegal camera status: %s',Status);
                    end
                    CameraObj(I).LogFile.writeLog(sprintf('waitFinish encounter an illegal camera status: %s',Status));
            end
        end
        if all(StopWaiting)
            Flag = true;
        end
    end
end
