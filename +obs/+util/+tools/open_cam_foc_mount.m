%function open_cam_foc_mount
% open a single camera, focuser and mount script
% Example: obs.util.tools.open_cam_foc_mount

%X = inst.XerxesMount;
%X.connect
M = obs.mount;
M.connect

F = obs.focuser;
F.connect

C = obs.camera;
C.connect(1,M,F);