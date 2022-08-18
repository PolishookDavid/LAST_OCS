%clear classes 
%P=obs.unitCS('02')
%P.connect
for i=1:4; P.Camera{i}.classCommand('Display=[];'); end

t0=now;
T=2; % hours
texp=5; % seconds
iexp=0;
while (now-t0)*24<T
    d=datestr(now);
    fprintf('%s\n\n',d)
    if mod(iexp,20)==0
       % P.focusLoop
    end
    if mod(iexp,5)==0
        P.Mount.goToTarget(P.Mount.LST-rand*120+60, rand*140-50)
    end
    P.takeExposure([],texp)
    iexp=iexp+1;
    pause(texp+5)
end

P.shutdown