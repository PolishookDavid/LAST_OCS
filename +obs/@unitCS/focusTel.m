function [Success, Result] = focusTel(UnitObj, itel, Args)
    % Focus a single telescope
    %   This routine can adaptively focus a single telescope, or set its
    %   focus position by a temperature-focus relation.
    % Input  : - The unit object.
    %          - focuser number 1,2,3, or 4.
    %          * ...,key,val,...
    %            'BacklashOffset' - Backlash offset.
    %                       sign indicate the backlash direction. If +,
    %                       then start with position larger than the
    %                       first guess focus value.
    %                       Default is +1000.
    %            'SearchHalfRange' - focus search upper half range.
    %                       Default is 200 to 500 depending on initial FWHM.
    %            'FWHM_Step' - [FWHM, step_size] two column matrix.
    %                       This will define an adaptive step size based on
    %                       the FWHM.
    %                       Default is [5 40; 20 60; 25 100]
    %            'PosGuess' - Guess focus position. If empty, use
    %                   current position.
    %            'ExpTime' - Image exposure time. Default is 3 [s].
    %            'PixScale' - Pixel scale. Default is 1.25 [arcsec/pix].
    %            'HalfSize' - Image half size in which to estimate focus.
    %                   Default is 1000.
    %            'fwhm_fromBankArgs' - A cell array of additional arguments
    %                   to pass to imUtil.psf.fwhm_fromBank
    %                   Default is {}.
    %            'MaxIter' - Maximum number of iterations. Default is 20.
    %            'MaxFWHM' - When estimating the FWHM min, use only values
    %                   with FWHM better than this vale. Default is 8 [arcsec].
    %            'MinNstars' - Min. required number of stars.
    %                   Default is 10.
    %             'Verbose' - Bool. Print numbers in slave session. Default
    %                       is true.
    %             'Plot' - Bool. Plot focus curve. Default is true.
    % Output : - A sucess flag.
    %          - A Result structure with the following fields:
    %            .Status
    %            .BestPos
    %            .BestFWHM
    %            .Counter
    % Author : Eran Ofek (Apr 2022) Nora (Jan. 2023), Enrico
    % Example: in Slave session P.focusTel(4);
    %          in Master session P.focusTel(1:4) (result not returned)
    
    arguments
        UnitObj
        itel                     = []; % telescopes to focus. [] means all
        
        Args.BacklashOffset      = +100;  % sign of the backlash direction
        Args.SearchHalfRange     = []; % if empty will choose small range if FWHM already good and large one otherwise
        Args.FWHM_Step           = [5 40; 15 60; 20 100]; % [FWHM, step size]
        Args.PosGuess            = [];  % empty - use current position
        
        Args.ExpTime             = 3;
        Args.PixScale            = 1.25;
        
        Args.ImageHalfSize       = 1000;
        Args.fwhm_fromBankArgs cell = {'SigmaVec',[0.1, logspace(0,1,25)].'}; %logspace(-0.5,2,25)};
        Args.MaxIter             = 20;
        Args.MaxFWHM             = 8;   % max FWHM to use for min estimation
       
        Args.MinNstars           = 10;
       
        Args.Verbose logical     = true;
        Args.Plot logical        = true;
        %Args.LogDir              = '/home/ocs/log'
        %Args.PlotDir             = '/home/ocs/log/focus_plots'
    end
    
    
    if isempty(itel)
       itel=1:numel(UnitObj.Camera);
    end
    
    UnitName=inputname(1);
    
    UnitObj.GeneralStatus='running focus loop';

    % make sure the mount is tracking
    %UnitObj.Mount.track;
    
    if numel(itel)==1 && ~isa(UnitObj.Camera{itel},'obs.remoteClass')
        % run, blocking, the scalar version of the method. Output arguments
        % are returned.
        [Success,Result] = UnitObj.focusTelInSlave(itel,Args);
    else
        % start the loops in the slaves. Not blocking, it will take a long
        %  time to complete. Outputs are not returned, they will need to be
        %  appositely inspected post-facto
        for i=itel
            % To pass Args, jencode them and tell the slave to jdecode
            % Nuisance: focusTelInSlave has to be public for the following
            %  to work, I'd like to make it private. But OTOH we can't call
            %  directly focusTel with Args as third argument
%             UnitObj.Slave{i}.Messenger.send([UnitName '.focusTelInSlave(' ...
%                                              num2str(i) ',jsondecode(''' ...
%                                              jsonencode(Args) ''') )']);
            % I can exploit this contraption, using namedargs2cell(Args)
            UnitObj.Slave{i}.Messenger.send(['NVargs=namedargs2cell(jsondecode(''' ...
                                             jsonencode(Args) ''') );'])
            UnitObj.Slave{i}.Messenger.send([UnitName '.focusTel(' ...
                                             num2str(i) ',NVargs{:} )']);
        end
    end