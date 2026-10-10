function paths = plot_case1_case2_refined_ser()
%PLOT_CASE1_CASE2_REFINED_SER Render logarithmic SER axes from frozen data.

root = dreSetupPaths(false);
folder = fullfile(root,'results','case1_case2_refined_ser');
loaded = load(fullfile(folder,'case1_case2_refined_ser.mat'),'result');
result = loaded.result;
if ~strcmp(result.status,'COMPLETE') || height(result.table)~=120 || ...
        numel(result.cells)~=20
    error('DRE:SerPlotSource','Complete 20-cell result is required.');
end
t = result.table;
config = result.config;
plotLabels = config.methodLabels;
plotLabels{1} = 'Huang-PREC V9';
seriesColors = [0 0.35 0.75; 0.85 0.325 0.098; ...
    0.85 0.55 0; 0.49 0.18 0.56; ...
    0.2 0.55 0.25; 0 0.6 0.65];
paths = strings(2,1);
for ci=1:2
    fig = figure('Visible','off','Color','w', ...
        'Position',[100 100 1180 650]);
    axesHandle = axes(fig);
    set(axesHandle,'YScale','log');
    hold(axesHandle,'on');
    minimumDisplayed = inf;
    handles=gobjects(numel(config.methodIds),1);
    % Draw the nearly coincident Case1 Huang curve last so its markers
    % remain visible above Stage55 without changing either data series.
    drawOrder=[2 3 4 5 6 1];
    for method=drawOrder
        rows=t.caseIndex==ci & ...
            t.methodId==string(config.methodIds{method});
        if sum(rows)~=10
            error('DRE:SerPlotRows','Expected ten SNR points per method.');
        end
        displayRate=max(t.ser(rows),0.5./t.symbolCount(rows));
        minimumDisplayed=min(minimumDisplayed,min(displayRate));
        if method==1
            handles(method)=plot(axesHandle,t.snrDb(rows),displayRate, ...
                'x--','Color',seriesColors(method,:), ...
                'LineWidth',1.4,'MarkerSize',8);
        else
            handles(method)=plot(axesHandle,t.snrDb(rows),displayRate, ...
                'o-','Color',seriesColors(method,:), ...
                'LineWidth',1.7,'MarkerSize',6);
        end
    end
    grid(axesHandle,'on');
    xlim(axesHandle,[-30 -21]);
    lowerLimit=10^floor(log10(minimumDisplayed));
    ylim(axesHandle,[lowerLimit 1.2]);
    decades=10.^(-5:0);
    yticks(axesHandle,decades(decades>=lowerLimit));
    xlabel(axesHandle,'SNR (dB)');
    ylabel(axesHandle,'SER (log scale)');
    title(axesHandle,sprintf('Case %d: SF12, 125 kHz, 1000 paired packets/SNR',ci));
    legend(axesHandle,handles,plotLabels, ...
        'Location','eastoutside');
    text(axesHandle,0.01,0.02, ...
        'Zero observed errors displayed at 0.5 / 112000 symbols', ...
        'Units','normalized','FontSize',8,'Color',[0.3 0.3 0.3]);
    if ci==1
        text(axesHandle,0.01,0.75, ...
            'Huang-PREC V9 and Stage55 V16 share the static decoder', ...
            'Units','normalized','FontSize',9,'Color',[0.2 0.2 0.2]);
    end
    paths(ci)=string(fullfile(folder, ...
        sprintf('Case%d_SER_vs_SNR_final.png',ci)));
    exportgraphics(fig,char(paths(ci)),'Resolution',220);
    close(fig);
end
end
