% testing the behavior of choking a superunit with messages. Are the
%  messages queued? Only the one received when the unit is free is served?
%  Do callbacks interrupt each other? Testing with a superunit which allows
%  mixing conversation with a Listener and with a callback Messenger
S.send('a=0;pause(4);a=1',1)
S.query('a',1)
for i=1:10
    S.query('a',1)
end


S.send('MasterResponder.Verbose=2')
S.send('MasterMessenger.Verbose=2')
S.send('i=0')
for i=1:100;S.send('pause(1);i=i+1');end

S.send('i=0')
for i=1:100;S.sendCallback('pause(1);i=i+1');end

S.query('MasterMessenger.StreamResource.BytesAvailable')
S.query('MasterResponder.StreamResource.BytesAvailable')
