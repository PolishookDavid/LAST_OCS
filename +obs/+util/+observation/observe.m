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
    %            'JD' - Julian day. Default is current UTC time.
    %            'CadenceMethod' - Cadence method:
    %                   Default is 'cycle'.
    %            'AbortFile' - File name that if exist, abort.
    %                   Default is '/home/ocs/abort'.
    % Output : - Update celestial.Targets object.
    %          - Number of sequences observed.
    % AUthor : Eran Ofek (Apr 2022)
    % Example: % case I: Cyclic observations of a 5 fields near the ecliptic.
    %          T=celestial.Targets; T.generateTargetList('last');
    %          JD = celestial.time.julday;
    %          [~,SI] = sort(leftVisibilityTime(T, JD), 'descend');
    %          [lon,lat]=T.ecliptic;
    %          I = find(abs(lat(SI))<5, 5, 'first');
    %          T.MaxNobs=zeros(size(T.RA)); T.MaxNobs(SI(I))=Inf;
    %          [Target, I]= obs.util.observation.observe(P, T);
    %
    %          % Case II: continues obsevartions of a single field
    %          T = celestial.Targets;
    %          T.RA = 213.11
    %          T.Dec = 34.1
    %          T.MaxNobs = Inf;
    %          [Target, I]= obs.util.observation.observe(P, T);
    
    
    arguments
        Unit obs.unitCS
        Target celestial.Targets
        Args.Cameras               = [];
        Args.ExpTime               = 20;
        Args.Nimages               = 20;
        Args.JD                    = celestial.time.julday;
        Args.ImType                = 'sci';
        Args.CadenceMethod         = 'cycle';
        Args.AbortFile             = '/home/ocs/abort';
        
        Args.Verbose logical       = true;
    end
   
    SeqTime =  Args.ExpTime.*Args.Nimages;
    JD = Args.JD;
    %JD = celestial.time.julday;
    [Target,PP,Ind] = Target.calcPriority(JD, Args.CadenceMethod);
    Ind = 1 % for debugging
    
    I = 0;
    Cont = true;
    while Cont
        I = I + 1; 
       
        if isempty(Ind)
            Cont = false;
            if Args.Verbose
                fprintf('Run out of targets\n')
            end
        else
            Ready = Unit.readyToExpose('Itel',[], 'Wait',true, 'Timeout',60);
            if exist(Args.AbortFile,'file')
                delete(Args.AbortFile);
                Ready = false;
                Cont  = false;
            end

            RA  = Target.RA(Ind(1));
            Dec = Target.RA(Ind(1));
            
            % for debuging during day time
            RA = Unit.Mount.LST + rand(1,1).*10;
            Dec = 30 + rand(1,1).*10;
            
            if Args.Verbose
                fprintf('goToTarget: RA=%f, Dec=%f [deg]\n',RA,Dec);
            end
            
            Unit.Mount.goToTarget(RA, Dec);
            %  Unit.Mount.waitFinish; % no need because we are loosing
            %  first exposure
            
            if Args.Verbose
                fprintf('takeExposure: %d images of %d seconds\n',Args.Nimages, Args.ExpTime);
            end
            
            Unit.takeExposure(Args.Cameras, Args.ExpTime, Args.Nimages, 'ImType',Args.ImType);
            pause(SeqTime);
            Unit.readyToExpose('Itel',Args.Cameras, 'Wait',true, 'Timeout',SeqTime);
            
            %JD = JD;  % for debuging during day time
            JD = celestial.time.julday;
            Target.GlobalCounter(Ind(1)) = Target.GlobalCounter(Ind(1)) + 1;
            [Target,PP,Ind] = Target.calcPriority(JD, Args.CadenceMethod);
            
        end

        if exist(Args.AbortFile,'file')
            delete(Args.AbortFile);
            Cont = false;
        end
    end
    
end