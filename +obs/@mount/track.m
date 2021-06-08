function track(MountObj,Rate)
    % Set tracking rate and start tracking
    % Input  : - Mount object.
    %          - [HA, Dec] speed, if scalar, than Dec speed is set
    %            to zero.
    %            String: 'sidereal' | 'sid' | 'lunar'          

    if nargin==2
        % set tracking rate
        MountObj.TrackingSpeed = Rate;
    elseif nargin==1
        Rate = MountObj.TrackingSpeed;
    else
        error('Illegal number of input arguments');
    end

    if MountObj.IsConnected
        MountObj.LogFile.writeLog('Start tracking')
        MountObj.Handle.track; % Driver will tarck at sidereal rate
    else
        MountObj.LogFile.writeLog(sprintf('Did not start tracking'));
    end
    MountObj.LastError = MountObj.Handle.LastError;
end
