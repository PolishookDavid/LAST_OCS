function plotFocusData(FocusData)
% tool to plot Unit.FocusData obtained by focus loops. Needs only that the
%  data is retrieved, and does not require to be run in the session which
%  collected the data, using its plotting capability
%
% Example usage:
% - in master: obs.util.observation.plotFocusData(Unit.FocusData)
% - in superunit session:
%    S.queryCallback('Unit.FocusData',9);
%    obs.util.observation.plotFocusData(ans{:})

    numplots=numel(FocusData);
    nx=floor(sqrt(numplots));
    ny=ceil(numplots/nx);

    clf;
    for i=1:numplots
        subplot(ny,nx,i)
        set(gca,'FontSize',10);
        ResTable=FocusData(i).ResTable;
        FocPos=[ResTable.FocPos];
        FWHM=[ResTable.FWHM];
        FlagGood=[ResTable.FlagGood];
        FlagGood=FlagGood(1:numel(FocPos)); % because it is initialized fully
        if ~isempty(FocPos)
            plot(FocPos(FlagGood), FWHM(FlagGood), 'bo', 'MarkerFaceColor','b');
            hold on
            plot(FocPos(~FlagGood), FWHM(~FlagGood), 'bo', 'MarkerFaceColor','w');
        end
        if ~isnan(FocusData(i).BestFWHM)
            plot(FocusData(i).BestPos,FocusData(i).BestFWHM,'ro', 'MarkerFaceColor','r')
        else
            text(FocusData(i).BestPos,24.5,...
                 sprintf('Nan at %d',FocusData(i).BestPos),...
                 'HorizontalAlignment','center','color','red')
        end
        % unitCS.focusTelInSlave also plots the fitting parabola, I don't
        %  know if I want to duplicate it here
        hold off
        grid on
        set(gca,'XtickLabel',string(get(gca,'Xtick')))
        title(sprintf('T%d - %s',i,FocusData(i).Status))
    end