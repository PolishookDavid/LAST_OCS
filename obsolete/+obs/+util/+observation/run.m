function run(UnitCS)
    %
    
    
    I = 0;
    while ~exist('/home/ocs/abort','file')
        pause(5);
        if UnitCS.readyToExpose('Itel',[], 'Wait',true,'Timeout',60)
            I = I + 1;
            I
            UnitCS.takeExposure([],20,20);

            pause(400);
        end
    end

    'done'


end