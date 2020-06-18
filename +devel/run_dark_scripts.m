Texp  = [0.1 , 1 , 3 , 10 , 30, 100];
Temp  = [15, 0 , -5,-15 ];
TempTresh=  0.2;
for Tempind = 1:numel(Temp)
    C.Temperature = Temp(Tempind);
    while (abs(C.Temperature-Temp(Tempind))>TempTresh)
        pause(5); 
        fprintf('%.2f\n', C.Temperature); 
    end
    j= 0 ;
    while (C.CoolingPercentage>95 && j<20)
        pause(5); 
        fprintf('%.2f\n', C.CoolingPercentage); 
        j=j+1;
    end
    
    disp(['Reached temperature - ' num2str(C.Temperature)]);
    for Texpind  = 1:numel(Texp)
        disp(['Start Texp = ' num2str(Texp(Texpind)) ', Temperature' num2str(Temp(Tempind))])
        C.takeDarkImages(5,Texp(Texpind))
        pause(10)   
    end
end
