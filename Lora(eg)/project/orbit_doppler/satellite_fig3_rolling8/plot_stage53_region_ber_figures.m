function imagePath = plot_stage53_region_ber_figures(resultDir)
%PLOT_STAGE53_REGION_BER_FIGURES Compare high-dynamic BER at both SNRs.
%   The figure uses the five-complete-pass Stage 53 aggregate statistics.

arguments
    resultDir (1,:) char = fullfile(fileparts(mfilename('fullpath')), ...
        'results','stage53_formal_repeated_passes')
end

summaryPath = fullfile(resultDir,'stage52_dynamic_region_summary.csv');
if ~isfile(summaryPath)
    error('SatelliteFig3:MissingStage53RegionSummary', ...
        'Stage 53 region summary was not found: %s',summaryPath);
end

summary = readtable(summaryPath,'TextType','string');
snrGridDb = unique(summary.snrDb,'stable');
methodKeys = ["Huang-PREC-static-CP","SenLoRa-VP"];
regionKey = "high_dynamic_ge_0p5_bin_per_frame";
values = nan(numel(snrGridDb),numel(methodKeys));
passes = nan;

for snrIndex = 1:numel(snrGridDb)
    for method = 1:numel(methodKeys)
        row = summary.snrDb == snrGridDb(snrIndex) & ...
            summary.dynamicRegion == regionKey & ...
            summary.method == methodKeys(method);
        if nnz(row) ~= 1
            error('SatelliteFig3:AmbiguousStage53RegionRow', ...
                'Expected one high-dynamic row for SNR %.1f and method %s.', ...
                snrGridDb(snrIndex),methodKeys(method));
        end
        values(snrIndex,method) = summary.ber(row);
        passes = summary.completedPasses(row);
    end
end

fig = figure('Visible','off','Color','w','Position',[80 80 1080 670]);
ax = axes(fig);
bars = bar(ax,values,'grouped','BarWidth',0.72);
hold(ax,'on');
colors = [0.85 0.15 0.10;0.00 0.35 0.85];
for method = 1:numel(bars)
    bars(method).FaceColor = colors(method,:);
    bars(method).EdgeColor = 'none';
end

maximum = max(values,[],'all');
ylim(ax,[0 1.34*maximum]);
xlim(ax,[0.45 numel(snrGridDb)+0.55]);
xticks(ax,1:numel(snrGridDb));
xticklabels(ax,compose('%g dB',snrGridDb));
xlabel(ax,'固定 SNR');
ylabel(ax,'高动态区域 BER（越低越好）');
grid(ax,'on');
ax.YGrid = 'on';
ax.XGrid = 'off';
ax.GridLineStyle = ':';
ax.GridAlpha = 0.28;
ax.Box = 'on';
ax.FontName = 'Microsoft YaHei';
ax.FontSize = 12;
ax.YAxis.Exponent = 0;

for method = 1:numel(bars)
    x = bars(method).XEndPoints;
    y = bars(method).YEndPoints;
    labels = compose('%.6f',values(:,method));
    text(ax,x,y + 0.025*maximum,labels, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontName','Times New Roman','FontSize',11);
end

reductionPercent = 100*(values(:,1)-values(:,2))./values(:,1);
for snrIndex = 1:numel(snrGridDb)
    text(ax,snrIndex,1.20*maximum, ...
        sprintf('SenLoRa BER 降低 %.1f%%',reductionPercent(snrIndex)), ...
        'HorizontalAlignment','center','FontName','Microsoft YaHei', ...
        'FontSize',12,'FontWeight','bold');
end

legend(ax,{'Huang static','SenLoRa'},'Location','northoutside', ...
    'Orientation','horizontal','Box','off','FontSize',11);
title(ax,{'Stage53 高动态区域：SenLoRa 在 -21 dB 与 -20 dB 均取得更低 BER', ...
    sprintf('%d 次完整过境统计',passes)}, ...
    'FontName','Microsoft YaHei','FontWeight','normal','FontSize',15);

base = 'stage53_high_dynamic_ber_minus21_minus20';
imagePath = fullfile(resultDir,[base '.png']);
exportgraphics(fig,imagePath,'Resolution',220);
savefig(fig,fullfile(resultDir,[base '.fig']));
close(fig);
end
