function files = plot_stage55_vp_quality_final_evaluation(options)
%PLOT_STAGE55_VP_QUALITY_FINAL_EVALUATION Paired full-pass effect intervals.

arguments
    options.ResultFolder (1,:) char = fullfile(fileparts( ...
        mfilename('fullpath')),'results', ...
        'stage55_vp_quality_final_evaluation')
end

summaryFile = fullfile(options.ResultFolder, ...
    'stage55_vp_ablation_summary.csv');
if ~isfile(summaryFile)
    error('SatelliteFig3:VpQualityFinalSummary', ...
        'Missing final VP-quality summary: %s',summaryFile);
end
summary = readtable(summaryFile);
quality = summary(strcmp(summary.mode,'VP-quality'),:);
expected = [-21 -21 -20 -20].';
regions = {'high_doppler_rate';'high_doppler_shift'; ...
    'high_doppler_rate';'high_doppler_shift'};
order = zeros(4,1);
for index = 1:4
    match = quality.snrDb == expected(index) & ...
        strcmp(quality.region,regions{index});
    if sum(match) ~= 1
        error('SatelliteFig3:VpQualityFinalGroups', ...
            'The final summary does not contain all four groups once.');
    end
    order(index) = find(match);
end
quality = quality(order,:);
if any(quality.independentPassCount < 2)
    error('SatelliteFig3:VpQualityFinalPassCount', ...
        'At least two independent complete passes are needed for intervals.');
end

labels = {'-21 dB, high rate','-21 dB, high shift', ...
    '-20 dB, high rate','-20 dB, high shift'};
figureHandle = figure('Visible','off','Color','w', ...
    'Position',[100 100 1550 700]);
layout = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
title(layout,sprintf(['Quality-aware virtual-pilot effect vs NoVP; ' ...
    '%d independent complete passes'], ...
    min(quality.independentPassCount)));

nexttile;
localEffectPlot(quality.pairedSerDeltaMean, ...
    quality.pairedSerDeltaCi95Lower, ...
    quality.pairedSerDeltaCi95Upper,labels, ...
    'Paired SER difference','SER difference (VP-quality - NoVP)');

nexttile;
localEffectPlot(quality.pairedCfoRmseDeltaMeanBins, ...
    quality.pairedCfoRmseDeltaCi95LowerBins, ...
    quality.pairedCfoRmseDeltaCi95UpperBins,labels, ...
    'Paired CFO tracking difference', ...
    'CFO RMSE difference (bin; VP-quality - NoVP)');

pngFile = fullfile(options.ResultFolder, ...
    'stage55_vp_quality_paired_effects_95ci.png');
figFile = fullfile(options.ResultFolder, ...
    'stage55_vp_quality_paired_effects_95ci.fig');
exportgraphics(figureHandle,pngFile,'Resolution',200);
savefig(figureHandle,figFile);
close(figureHandle);
files = {pngFile;figFile};
fprintf('Stage55 VP-quality paired-effect figure: %s\n',pngFile);
end

function localEffectPlot(meanValue,lower,upper,labels,plotTitle,yLabel)
x = (1:numel(meanValue)).';
lowerLength = meanValue-lower;
upperLength = upper-meanValue;
errorbar(x,meanValue,lowerLength,upperLength,'o', ...
    'LineWidth',1.6,'MarkerSize',8, ...
    'MarkerFaceColor',[0.85 0.325 0.098], ...
    'Color',[0.85 0.325 0.098]);
hold on
yline(0,'k--','LineWidth',1.2);
grid on
xlim([0.5 numel(meanValue)+0.5]);
set(gca,'XTick',x,'XTickLabel',labels,'XTickLabelRotation',18);
ylabel(yLabel);
title(plotTitle);
end
