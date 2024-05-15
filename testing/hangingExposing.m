% testing slave hangs on exposure after having merged with multimessenger
for i=1:2
    if any(strcmp(Unit.Slave(i).Status,{'dead','disconnected'}))
        Unit.Slave(i).kill;
        Unit.connectSlave(i);
    end
end

for i=1:2
    Unit.Camera{i}.classCommand('Verbose=2;');
    Unit.Camera{i}.classCommand(sprintf('connect(Unit.Camera{%d}.allQHYCameraNames{%d})',i,i));
end

Unit.takeExposure(1:2,6)