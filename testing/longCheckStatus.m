diary('~/unitCheck.log')
while true
    d=datestr(now);
    status=P.checkWholeUnit(1,1);
    if status
        fprintf('%s - CHECK PASSED\n\n\n',d)
    else
        fprintf('%s - CHECK FAILED\n\n\n',d)
    end
    pause(5)
end