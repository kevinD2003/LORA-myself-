function result = run_paper_table_iv(options)
%RUN_PAPER_TABLE_IV Reproduce and compare the paper's Table IV.

arguments
    options.MaximumPackets (1,1) double {mustBePositive} = inf
    options.SnrDb (:,1) double = [0;-5;-10;-15;-20]
end
root = dreSetupPaths(false);
config = drePaperConfig();
config.maximumPackets = options.MaximumPackets;
config.snrDb = options.SnrDb;
signature = dreConfigurationSignature(config);
output = fullfile(root,'results','paper_reproduction');
if ~isfolder(output), mkdir(output); end
matPath = fullfile(output,'table_iv_run.mat');
if isfile(matPath)
    existing = load(matPath,'result');
    if isfield(existing,'result') && strcmp(existing.result.signature,signature)
        result = existing.result;
        localWriteSidecars(result.table,output);
        fprintf('Reusing paper-anchor result with matching signature.\n');
        return
    end
end
rows = repmat(dreRunPaperOverpass(config.snrDb(1),config),numel(config.snrDb),1);
for k = 2:numel(config.snrDb)
    rows(k) = dreRunPaperOverpass(config.snrDb(k),config);
end
snr = vertcat(rows.snrDb);
tableOut = table(snr,vertcat(rows.packetCount),vertcat(rows.payloadSymbolCount), ...
    100*vertcat(rows.adaptiveSer),100*vertcat(rows.fixedSer), ...
    vertcat(rows.adaptiveMeanErrorMagnitude),vertcat(rows.fixedMeanErrorMagnitude), ...
    'VariableNames',{'snrDb','packetCount','payloadSymbols', ...
    'adaptiveSerPercent','fixedSerPercent','adaptiveMeanErrorMagnitude', ...
    'fixedMeanErrorMagnitude'});
paperAdaptive = nan(size(snr)); paperFixed = nan(size(snr));
paperAdaptiveMagnitude = nan(size(snr)); paperFixedMagnitude = nan(size(snr));
for k = 1:numel(snr)
    index = find(config.snrDb(k)==[0 -5 -10 -15 -20],1);
    if ~isempty(index)
        paperAdaptive(k) = config.paperAdaptiveSerPercent(index);
        paperFixed(k) = config.paperFixedSerPercent(index);
        paperAdaptiveMagnitude(k) = config.paperAdaptiveMeanErrorMagnitude(index);
        paperFixedMagnitude(k) = config.paperFixedMeanErrorMagnitude(index);
    end
end
tableOut.paperAdaptiveSerPercent = paperAdaptive;
tableOut.paperFixedSerPercent = paperFixed;
tableOut.paperAdaptiveMeanErrorMagnitude = paperAdaptiveMagnitude;
tableOut.paperFixedMeanErrorMagnitude = paperFixedMagnitude;
tableOut.adaptiveSerDeltaPercentagePoints = tableOut.adaptiveSerPercent-paperAdaptive;
tableOut.fixedSerDeltaPercentagePoints = tableOut.fixedSerPercent-paperFixed;
tableOut.adaptiveMeanErrorMagnitudeDelta = ...
    tableOut.adaptiveMeanErrorMagnitude-paperAdaptiveMagnitude;
tableOut.fixedMeanErrorMagnitudeDelta = ...
    tableOut.fixedMeanErrorMagnitude-paperFixedMagnitude;
localWriteSidecars(tableOut,output);
result = struct('status','COMPLETE','signature',signature,'config',config, ...
    'rows',rows,'table',tableOut,'paperSource','WSA 2025 Table IV', ...
    'receiverUsesPayloadTruth',false);
save(matPath,'result','-v7.3');
end

function localWriteSidecars(tableOut,output)
writetable(tableOut,fullfile(output,'table_iv_reproduction.csv'));
snr = tableOut.snrDb;
figure('Visible','off','Color','w','Position',[100 100 1000 430]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;
plot(snr,tableOut.adaptiveSerPercent,'o-','LineWidth',1.6); hold on;
plot(snr,tableOut.fixedSerPercent,'s-','LineWidth',1.6);
plot(snr,tableOut.paperAdaptiveSerPercent,'o--','LineWidth',1.2);
plot(snr,tableOut.paperFixedSerPercent,'s--','LineWidth',1.2);
grid on; xlabel('SNR (dB)'); ylabel('SER (%)');
title('Table IV: SER');
legend('Adaptive LR reproduced','Fixed LR reproduced', ...
    'Adaptive LR paper','Fixed LR paper','Location','northwest');
nexttile;
plot(snr,tableOut.adaptiveMeanErrorMagnitude,'o-','LineWidth',1.6); hold on;
plot(snr,tableOut.fixedMeanErrorMagnitude,'s-','LineWidth',1.6);
plot(snr,tableOut.paperAdaptiveMeanErrorMagnitude,'o--','LineWidth',1.2);
plot(snr,tableOut.paperFixedMeanErrorMagnitude,'s--','LineWidth',1.2);
grid on; xlabel('SNR (dB)'); ylabel('Mean error magnitude (bins)');
title('Table IV: erroneous-symbol magnitude');
legend('Adaptive LR reproduced','Fixed LR reproduced', ...
    'Adaptive LR paper','Fixed LR paper','Location','northwest');
exportgraphics(gcf,fullfile(output,'table_iv_comparison.png'),'Resolution',180);
close(gcf);
end
