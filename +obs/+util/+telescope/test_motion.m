function test_motion(M)
% telescope pointing stress test on grid of coordinates
%
% Input: a local mount object
%
% Example: obs.util.tools.test_motion(M)

RAD = 180./pi;

List=obs.util.tools.hadec_grid('NstepGC',10);
N = numel(List.HA);


for I=1:1:N
    fprintf('Pointing number %d out of %d\n',I,N);
    HA = List.HA(I);
    Dec = List.Dec(I);
    
    JD = celestial.time.julday;
    LST = celestial.time.lst(JD,34.9./RAD);
    % HA = LST - RA
    RA  = LST.*360 - HA;
    
    M.goTo(RA,Dec);
    %M.goTo(0,Dec);
    %M.goto(RA,Dec,'InCooType','t2021.1');
   
   
    pause(1);
    
    % compare desired coordinates to actual coordinates
    (M.RA - RA).*3600
    (M.Dec - Dec).*3600
    
    
    if any(cell2mat(struct2cell(M.FullStatus.Dec)))
        M.FullStatus.Dec
        %error('Dec Problem')
    end
%     if any(cell2mat(struct2cell(M.FullStatus.HA)))
%         M.FullStatus.HA
%         %error('HA Problem')
%     end
    
end