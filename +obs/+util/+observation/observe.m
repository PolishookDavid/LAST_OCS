function [Target, I]= observe(Unit, Target, Args)
    % observe targets in celestial.Targets object
    %   Given a UnitCS object and a celestial.Targets object, select
    %   targets to observe and execute the observations.
    %   In order to stop the script create an abort file - e.g., "cd /home/ocs/; touch abort"
    % Input  : - A UnitCS object.
    %          - A celestial.Targets object. See examples.
    %          * ...,key,val,...
    %            'Cameras' - Cameras to use. [] for all. Default is [].
    %            'ExpTime' - Exp time. Default is 20.
    %            'Nimages' - Number of images in a sequence. Default is 20.
    %            'ImType' - Image type. Default is 'sci'.
    %            'CadenceMethod' - Cadence method:
    %                   Default is 'cycle'.
    %            'AbortFile' - File name that if exist, abort.
    %                   Default is '/home/ocs/abort'.
    % Output : - Update celestial.Targets object.
    %          - Number of sequences observed.
    % AUthor : Eran Ofek (Apr 2022)
    % Example: % case I: Cyclic observations of a 5 fields near the ecliptic.
    %          T=celestial.Targets; T.generateTargetList('last');
    %          [~,SI] = sort(leftVisibilityTime(T, JD), 'descend');
    %          [lon,lat]=T.ecliptic;
    %          I = find(abs(lat(SI))<5, 5, 'first');
    %          T.MaxNobs=zeros(size(T.RA)); T.MaxNobs(SI(I)))=Inf;
    %          [Target, I]= obs.util.observation.observe(P, T);
    %
    %          % Case II: continues obsevartions of a single field
    %          T = celestial.Targets;
    %          T.RA = 213.11
    %          T.Dec = 34.1
    %          T.MaxNobs = Inf;
    %          [Target, I]= obs.util.observation.observe(P, T);
    
    
    arguments
        Unit unitCS
        Target celestial.Targets
        Args.Cameras               = [];
        Args.ExpTime               = 20;
        Args.Nimages               = 20;
        Args.ImType                = 'sci';
        Args.CadenceMethod         = 'cycle';
        Args.AbortFile             = '/home/ocs/abort';
        
    end
   
    SeqTime =  Args.ExpTime.*Args.Nimages;
    JD = celestial.time.julday;
    [Target,PP,Ind] = Target.calcPriority(JD, Args.CadenceMethod);
    
    I = 0;
    while Cont
        I = I + 1; 
       
        if isempty(Ind)
            Cont = false;
        else
            RA  = Target.RA(Ind(1));
            Dec = Target.RA(Ind(1));
            
            Unit.Mount.goToTarget(RA, Dec);
            %  Unit.Mount.waitFinish; % no need because we are loosing
            %  first exposure
            
            Ready = Unit.readyToExpose;
            while ~Ready
                if exist(Args.AbortFile,'file')
                    delete(Args.AbortFile);
                    Ready = false;
                    Cont  = false;
                end
                pause(2);
            end
            
            Unit.takeExposure(Args.Cameras, Args.ExpTime, Args.Nimages, 'ImType',Args.ImType);
            pause(SeqTime);
            
            JD = celestial.time.julday;
            [Target,PP,Ind] = Target.calcPriority(JD, Args.CadenceMethod);
            
        end

        if exist(Args.AbortFile,'file')
            delete(Args.AbortFile);
            Cont = false;
        end
    end
    
end