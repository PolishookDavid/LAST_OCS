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
    %                   with FWHM better than this value. Default is 8 [arcsec].
    %            'MinNstars' - Min. required number of stars.
    %                   Default is 10.
    %            'Verbose' - Bool. Print numbers in slave session. Default
    %                       is true.
    %            'Plot' - Bool. Plot focus curve. Default is true.
    %            'Timeout' - seconds, terminate the focus loop if not completed
    %                       this time
    % Output : - A sucess flag.
    %          - A Result structure with the following fields:
    %            .Status
    %            .BestPos
    %            .BestFWHM
    %            .Counter
    % Author : Eran Ofek (Apr 2022) Nora (Jan. 2023), Enrico
    % Example: in Slave session P.focusTel(4); (single itel!)
    %          in Master session P.focusTel(1:4) (result not returned for telescopes
    %                                             controlled by a 'messenger' Messenger)
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
        Args.Timeout             = 300;
    end
    
    
    if isempty(itel)
       itel=1:numel(UnitObj.Camera);
    end
    
    UnitName=inputname(1);
    
    UnitObj.GeneralStatus='running focus loop';
    % in the master this is a call and forget - someone sometime will have
    %  to check for completion and update .GeneralStatus

    % make sure the mount is tracking
    %UnitObj.Mount.track;
    
    t0=now;
    if numel(itel)==1 && ~isa(UnitObj.Camera{itel},'obs.remoteClass')
        % run, blocking, the scalar version of the method. Output arguments
        % are returned.
        [Success,Result] = UnitObj.focusTelInSlave(itel,Args);
        UnitObj.GeneralStatus='focus loop terminated'; % this in the slave...
    else
        % this is run in the master. We could alternatively check for
        %  Unit.Master=true
        UnitObj.constructUnitHeader;
        headerline=obs.util.tools.headerInputForm(UnitObj.UnitHeader);
        % here we assume implicitly that we have one camera per Slave, and that
        %  all Cameras are remote
        listener=false(1,numel(UnitObj.Slave));
        for i=itel
            UnitObj.Slave(i).Messenger.send(sprintf('%s.UnitHeader=%s;',UnitName,headerline));
            % To pass Args, jencode them and tell the slave to jdecode
            % I can exploit this contraption, using namedargs2cell(Args)
            UnitObj.Slave(i).Messenger.send(['NVargs=namedargs2cell(jsondecode(''' ...
                                            jsonencode(Args) '''));']);
            % start the loops in the slaves. Not blocking, it will take a long
            %  time to complete. Outputs are not returned, they will need to be
            %  appositely inspected post-facto
            UnitObj.Slave(i).Messenger.send([UnitName '.focusTel(' ...
                                            num2str(i) ',NVargs{:});']);
            % check if slaves are driven via a listener. If so, we can
            %  query them with callbacks for the progress of the focusing. If not,
            %  queries would be enqueued after the command, and we cannot,
            %  so we're forced to call and forget
            listener(itel)= strcmpi(UnitObj.Slave(i).RemoteMessengerFlavor,'listener');
        end
        Success=false(1,numel(itel));
        StatusStrings=cell(1,numel(itel));
        if any(listener)
            % query periodically all the slaves with listeners, and
            %  exit only when the last one of them has
            %  UnitObj.FocusData.LoopCompleted, with a timeout.
            completed=false;
            while (now-t0)*86400<Args.Timeout && ~completed
                completed=true;
                for i=itel(listener(itel))
                    try
                        UnitObj.FocusData(i)=...
                              obs.FocusData(UnitObj.Slave(i).Responder.query(...
                                      sprintf('%s.FocusData(%d);',UnitName,i)));
                        completed = completed && UnitObj.FocusData(i).LoopCompleted;
                        % prepare strings for updating Unit.GeneralStatus
                        %  with a short formatting of the ongoing results
                        %  (i.e. FocusData.Counter, and if completed)
                        if ~isempty(UnitObj.FocusData(i).Status)
                            if ~isnan(UnitObj.FocusData(i).BestFWHM)
                                StatusStrings{i}=sprintf('T%d OK ',i);
                            else
                                StatusStrings{i}=sprintf(' T%d FAIL ',i);
                            end
                        else
                            if ~isempty(UnitObj.FocusData(i).Counter) && ...
                                    ~isnan(UnitObj.FocusData(i).Counter)
                                StatusStrings{i}=sprintf(' T%d [#%d] ',i,...
                                              UnitObj.FocusData(i).Counter);
                            else
                                StatusStrings{i}=sprintf(' T%d [--] ',i);
                            end
                        end
                    catch
                        completed=false;
                        StatusStrings{i}=sprintf(' T%d [?] ',i);
                    end
                end
                UnitObj.GeneralStatus=['Focusing:' strjoin(StatusStrings(itel),'/')];
            end
            if ~completed
                UnitObj.abort;
            end
            % results are returned only for telescopes powered by listeners
            for i=itel
                Success(i)=~isempty(UnitObj.FocusData(i).Status) && ...
                           ~isnan(UnitObj.FocusData(i).BestFWHM);
            end
            % fuck you, I have enough of unpacking and repacking, just
            %  return all of it
            Result=UnitObj.FocusData;
        else
            % we cannot block and query, hence exit here
            % define the return arguments as empty, in order not to generate
            %  errors [and to avoid a double evaluation within the try-catch of
            %  datagram parser, once without and once with return argument
            Success=[];
            Result=[];
        end
    end