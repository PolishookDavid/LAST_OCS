function debugging(P,tof)
% taylored for turning debugging logs on or off with the present
%  structure of 4 slaves across two computers
    if ~isempty([P.Slave{1}.PID,P.Slave{2}.PID,P.Slave{3}.PID,P.Slave{4}.PID])
        fprintf('the debugging status can only be changed when slaves are disconnected!\n')
        return
    end
    for i=1:4
        P.Slave{i}.Logging=tof;
        P.Slave{i}.LoggingDir=fullfile('/',P.Slave{i}.Host,'data1','archive','Logs');
    end
    P.connect
    for i=1:4
        P.Camera{i}.classCommand('DebugOutput=%d;',tof);
        P.Camera{i}.classCommand('DebugLogLevel=5;');
    end

    
