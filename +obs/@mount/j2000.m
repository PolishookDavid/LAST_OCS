function [RAJ,DecJ,HAJ,JD,Aux]=j2000(MountObj,varargin)
    % get J2000.0 distortion corrected coordinates of the mount
    % Input   : - Mount object
    %           - Additional pairs of parameters to pass to celestial.coo.convert2equatorial
    %             Default is no parameters.
    % Output  : - J2000.0 RA [deg]
    %           - J2000.0 Dec [deg]
    %           - J2000.0 HA [deg]
    %           - JD at which the HA was calculated
    %           - Auxilary parameters - see celestial.coo.convert2equatorial

    RAD = 180./pi;
    OutputCooType = 'J2000';

    % read coordinates from mount
    MRA  = MountObj.RA;
    MDec = MountObj.Dec;
    JD  = celestial.time.julday;
    LST = celestial.time.lst(JD,MountObj.ObsLon./RAD,'a').*360;  % [deg]
   
    try
        InCooType=MountObj.CoordType;
    catch
        MountObj.report('coordinate system not given - assuming Equinox of date');
        InCooType = 'tdate';
    end
    
    % input/output are in deg
    [RAJ, DecJ, Aux] = celestial.coo.convert2equatorial(MRA, MDec, varargin{:},'InCooType',InCooType,'OutCooType',OutputCooType);
    HAJ        = LST - RAJ;  % [deg]
    % set HAJ to -180 to 180 deg range
    HAJ        = mod(HAJ,360);
    HAJ(HAJ>180) = HAJ(HAJ>180) -360;


end
