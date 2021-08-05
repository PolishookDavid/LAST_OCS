function [HA,Dec]=distortion_fun(ReqHA,ReqDec)
% Distortion correction for HA/Dec (T-Point map)
% Package: +obs.util.tools
% Description: Given the requested HA/Dec
% Input  : - Requested HA [rad]
%          - Requested Dec [rad]
% Output : - HA to feed mount in order for the mount to point at the
%            requested HA [rad].
%          - Dec to feed mount in order for the mount to point at the
%            requested Dec [rad].
%     By : Eran Ofek                     Aug 2020
% Example: [HA,Dec]=obs.util.tools.distortion_fun(ReqHA,ReqDec)

HA  = ReqHA;
Dec = ReqDec;
