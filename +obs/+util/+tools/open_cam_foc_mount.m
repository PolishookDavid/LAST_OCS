%function open_cam_foc_mount
% open a single camera, focuser and mount script


X = inst.XerxesMount;
X.connect

F = obs.focuser;
F.connect

C = obs.camera;
C.connect