function randomMotion(Unit, Args)
    % Test random motion
    % Example: obs.util.align.randomMotion
   
    arguments
        Unit
        Args.Npt      = 50;
        Args.MinAlt   = 30; % [deg]
        Args.ObsCoo   = [35, 30]
    end
    
    RAD = 180./pi;
    
    % make points
    RandCoo = tools.math.stat.cel_coo_rnd(Args.Npt,'RejLatRange',[-90 Args.MinAlt]./RAD);    
    [HA,Dec]=celestial.coo.azalt2hadec(RandCoo(:,1),RandCoo(:,2),Args.ObsCoo(2)./RAD,'rad');
    HA  = HA.*RAD;
    Dec = Dec.*RAD;
    for Ipt=1:1:Args.Npt
        fprintf('Movig to HA=%f, Dec=%f\n',HA(Ipt), Dec(Ipt));
        
        Unit.Mount.goTo(HA(Ipt), Dec(Ipt), 'ha');
        Unit.Mount.waitFinish;
        pause(2);
    end
    
        
end