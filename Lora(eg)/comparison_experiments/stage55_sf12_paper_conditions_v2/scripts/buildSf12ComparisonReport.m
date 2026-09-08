function overhead = buildSf12ComparisonReport()
%BUILDSF12COMPARISONREPORT Build Figures A/B and native-overhead Table B.

root = sf12SetupPaths();
cfg = sf12PaperCommonConfig();
layout = sf12BuildFrameLayout(cfg);
formalFolder = fullfile(root,'results','formal_common_frame');
summaryFile = fullfile(formalFolder,'sf12_formal_summary.csv');
assert(isfile(summaryFile),'Formal summary does not exist.');
data = readtable(summaryFile,'TextType','string');
writetable(data,fullfile(formalFolder,'table_a_ser_cfo_summary.csv'));
for caseName = ["case1","case2"]
    figureHandle = figure('Visible','off','Color','w');
    axesHandle = axes('Parent',figureHandle);
    hold(axesHandle,'on'); grid(axesHandle,'on');
    for method = ["Paper-Midamble-Point","Stage55-VP-quality-SER"]
        rows = sortrows(data(data.caseName == caseName & ...
            data.method == method,:), 'snrDb');
        semilogy(axesHandle,rows.snrDb,rows.ser,'-o','LineWidth',1.5, ...
            'DisplayName',method);
    end
    xlabel(axesHandle,'SNR [dB]'); ylabel(axesHandle,'SER');
    xlim(axesHandle,[min(cfg.monteCarlo.snrDb), ...
        max(cfg.monteCarlo.snrDb)]);
    xticks(axesHandle,cfg.monteCarlo.snrDb);
    set(axesHandle,'YScale','log','YLim',[1e-2,1], ...
        'YTick',[1e-2,1e-1,1]);
    axesHandle.XMinorGrid = 'off';
    axesHandle.YMinorGrid = 'on';
    title(axesHandle,sprintf('SF12 %s: paired common-frame SER',caseName));
    legend(axesHandle,'Location','best');
    exportgraphics(figureHandle,fullfile(formalFolder, ...
        sprintf('figure_%s_ser_snr.png',caseName)),'Resolution',180);
    close(figureHandle);
end
states = cell(2,1);
caseNames = ["case1","case2"];
for caseIndex = 1:2
    checkpoint = fullfile(formalFolder,sprintf('%s_%+03ddB_checkpoint.mat', ...
        caseNames(caseIndex),-21));
    assert(isfile(checkpoint),'Representative -21 dB checkpoint is missing.');
    loaded = load(checkpoint,'state');
    states{caseIndex} = loaded.state;
end
figureHandle = figure('Visible','off','Color','w');
tiles = tiledlayout(figureHandle,2,1,'TileSpacing','compact');
for caseIndex = 1:2
    axesHandle = nexttile(tiles); hold(axesHandle,'on'); grid(axesHandle,'on');
    state = states{caseIndex};
    plot(axesHandle,sqrt(state.paperCfoSseBySymbol/state.packets), ...
        '-o','DisplayName','Paper-Midamble-Point');
    plot(axesHandle,sqrt(state.stage55CfoSseBySymbol/state.packets), ...
        '-s','DisplayName','Stage55-VP-quality-SER');
    ylabel(axesHandle,'CFO RMSE (Hz)');
    title(axesHandle,sprintf('%s, SNR=-21 dB',caseNames(caseIndex)));
end
xlabel(tiles,'Payload symbol index'); legend(axesHandle,'Location','best');
exportgraphics(figureHandle,fullfile(formalFolder, ...
    'figure_c_minus21db_symbol_cfo_rmse.png'),'Resolution',180);
close(figureHandle);

figureHandle = figure('Visible','off','Color','w');
tiles = tiledlayout(figureHandle,2,1,'TileSpacing','compact');
for caseIndex = 1:2
    axesHandle = nexttile(tiles); hold(axesHandle,'on'); grid(axesHandle,'on');
    state = states{caseIndex};
    stem(axesHandle,layout.midambleAfterDataIndex(1:7), ...
        ones(7,1),'DisplayName','Paper effective Midamble');
    plot(axesHandle,1:cfg.frame.payloadSymbolCount, ...
        state.stage55AcceptedBySymbol/state.packets,'-o', ...
        'DisplayName','Stage55 VP acceptance rate');
    ylim(axesHandle,[0,1.2]); ylabel(axesHandle,'Pilot event');
    title(axesHandle,sprintf('%s, aggregate at -21 dB', ...
        caseNames(caseIndex)));
end
xlabel(tiles,'Payload symbol index'); legend(axesHandle,'Location','best');
exportgraphics(figureHandle,fullfile(formalFolder, ...
    'figure_d_pilot_positions_and_coverage.png'),'Resolution',180);
close(figureHandle);

pairedRows = table();
for caseIndex = 1:numel(caseNames)
    for snrIndex = 1:numel(cfg.monteCarlo.snrDb)
        snrDb = cfg.monteCarlo.snrDb(snrIndex);
        checkpoint = fullfile(formalFolder,sprintf('%s_%+03ddB_checkpoint.mat', ...
            caseNames(caseIndex),snrDb));
        loaded = load(checkpoint,'state');
        state = loaded.state;
        difference = (state.stage55ErrorsPerPacket- ...
            state.paperErrorsPerPacket)/cfg.frame.payloadSymbolCount;
        interval = localPairedBootstrapInterval(difference, ...
            2027130000+100*caseIndex+snrIndex);
        row = table(caseNames(caseIndex),snrDb,state.packets, ...
            mean(difference),interval(1),interval(2), ...
            'VariableNames',{'caseName','snrDb','packets', ...
            'stage55MinusPaperSer','pairedCi95Low','pairedCi95High'});
        pairedRows = [pairedRows;row]; %#ok<AGROW>
    end
end
writetable(pairedRows,fullfile(formalFolder, ...
    'table_c_paired_packet_ser_difference.csv'));

method = ["Paper-Midamble-Point";"Stage55-VP-quality-SER"];
prefixChirpEquivalents = cfg.frame.preambleUpchirps+ ...
    cfg.frame.completeDownchirps+cfg.frame.synchronizationFractionalChirps;
transmittedSymbols = prefixChirpEquivalents+[ ...
    layout.physicalSymbolCount;cfg.frame.payloadSymbolCount];
explicitPilots = [cfg.frame.toaMidambleCount;0];
toaSec = [layout.paperNativeToaSec;layout.stage55NativeToaSec];
payloadSymbols = repmat(cfg.frame.payloadSymbolCount,2,1);
netPayloadSymbolRate = payloadSymbols./toaSec;
energyProxyChirpEquivalents = transmittedSymbols;
overhead = table(method,transmittedSymbols,explicitPilots,toaSec, ...
    payloadSymbols,netPayloadSymbolRate,energyProxyChirpEquivalents);
folder = fullfile(root,'results','native_overhead');
if ~isfolder(folder), mkdir(folder); end
writetable(overhead,fullfile(folder,'table_b_native_overhead.csv'));
end

function interval = localPairedBootstrapInterval(difference,seed)
%LOCALPAIREDBOOTSTRAPINTERVAL Packet-cluster paired percentile interval.

oldRng = rng;
cleanup = onCleanup(@()rng(oldRng));
rng(seed,'twister');
n = numel(difference);
replicateCount = 2000;
replicates = zeros(replicateCount,1);
for replicate = 1:replicateCount
    replicates(replicate) = mean(difference(randi(n,n,1)));
end
replicates = sort(replicates);
lowerIndex = max(1,ceil(0.025*replicateCount));
upperIndex = min(replicateCount,ceil(0.975*replicateCount));
interval = [replicates(lowerIndex),replicates(upperIndex)];
end
