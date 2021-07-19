function spawn(host,localport,remoteport)
% spawns one instance of matlab, creating a messenger in it

if ~exist('host','var')
    host='localhost';
end
if ~exist('localport','var')
    localport=8001;
end
if ~exist('remoteport','var')
    remoteport=8002;
end
matlabcommand='closeNoPrompt(matlab.desktop.editor.getAll);';
messengercommand = sprintf(['MasterMessenger=obs.util.Messenger(''%s'',%d,%d);'...
                            'MasterMessenger.connect;'],...
                            host,localport,remoteport);
if strcmp(host,'localhost')
    spawncommand='matlab -nosplash -desktop -r ';
    system([spawncommand '"' matlabcommand messengercommand '"&'])
else
    % could use rsh (but if we want to open a window on a display,
    %   more complicate)
end

% create a listener messenger too in the base workspace
Listener=obs.util.Messenger(host,remoteport,localport);
% live dangerously: connect the local messenger, pass to base the copy
Listener.connect;
assignin('base',sprintf('Spawn%d',remoteport),Listener);
