function [success,pid]=spawn(host,localport,remoteport)
% spawns one instance of matlab, creating a messenger in it

% I was considering to promote this to the constructor of a hypotetical
%  class SpawnedMatlab. Its destructor would send a Messenger.send('exit').
%  But there would be the problem of nonresponding busy sessions. If they
%  were identified by pid, there could be a .kill method...

if ~exist('host','var')
    host='localhost';
end
if ~exist('localport','var')
    localport=8001;
end
if ~exist('remoteport','var')
    remoteport=8002;
end
desktopcommand = ['closeNoPrompt(matlab.desktop.editor.getAll); ', ...
                 'jDesktop = com.mathworks.mde.desk.MLDesktop.getInstance; ', ...
                 sprintf('jDesktop.getMainFrame.setTitle(''spawn %d->%d''); ',...
                         remoteport,localport)];

messengercommand = sprintf(['MasterMessenger=obs.util.Messenger(''%s'',%d,%d);'...
                            'MasterMessenger.connect;'],...
                             char(java.net.InetAddress.getLocalHost.getHostName),...
                             localport,remoteport);
% java trick to get hostname from matlabcentral

% we could check at this point: if there is already a corresponding Spawn 
%  messenger, and if it talks to a session (areYouThere), don't proceed.

if strcmp(host,'localhost')
%    spawncommand='matlab -nosplash -desktop -r ';
%    success= (system([spawncommand '"' desktopcommand messengercommand '"&'])==0);
    spawncommand='gnome-terminal -- matlab -nosplash -nodesktop -r ';
    success= (system([spawncommand '"' messengercommand '"&'])==0);
else
    % could use rsh (but if we want to open a window on a display,
    %   more complicate)
end

% create a listener messenger
Listener=obs.util.Messenger(host,remoteport,localport);
% live dangerously: connect the local messenger, pass to base the copy
Listener.connect; % can fail if the local port is busy

if nargout==2
    v=Listener.Verbose;
    Listener.Verbose=false;
    retries=3; i=0;
    while ~Listener.areYouThere && i<retries
        % retry enough time for the spawned session to be ready, tune it
        i=i+1;
    end
    Listener.Verbose=v;
    pid=Listener.query('feature(''getpid'')');
end

% copy the listener in the base workspace, the local one is destroyed on
%  return
assignin('base',sprintf('Spawn%d',remoteport),Listener);
