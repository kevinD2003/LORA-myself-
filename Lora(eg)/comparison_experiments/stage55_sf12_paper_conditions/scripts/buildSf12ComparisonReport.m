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
    xlabel(axesHandle,'SNR (dB)'); ylabel(axesHandle,'Payload SER');
    title(axesHandle,sprintf('SF12 %s: paired common-frame SER',caseName));
    legend(axesHandle,'Location','best');
    exportgraphics(figureHandle,fullfile(formalFolder, ...
        sprintf('figure_%s_ser_snr.png',caseName)),'Resolution',180);
    close(figureHandle);
end
representative = cell(2,1);
caseNames = ["case1","case2"];
for caseIndex = 1:2
    checkpoint = fullfile(formalFolder,sprintf('%s_%+03ddB_checkpoint.mat', ...
        caseNames(caseIndex),-21));
    assert(isfile(checkpoint),'Representative -21 dB checkpoint is missing.');
    loaded = load(checkpoint,'state');
    representative{caseIndex} = loaded.state.trace;
end
figureHandle = figure('Visible','off','Color','w');
tiles = tiledlayout(figureHandle,2,1,'TileSpacing','compact');
for caseIndex = 1:2
    axesHandle = nexttile(tiles); hold(axesHandle,'on'); grid(axesHandle,'on');
    trace = representative{caseIndex};
    plot(axesHandle,trace.paperEstimatedCfoHz-trace.trueDataCfoHz, ...
        '-o','DisplayName','Paper-Midamble-Point');
    plot(axesHandle,trace.stage55EstimatedCfoHz-trace.trueDataCfoHz, ...
        '-s','DisplayName','Stage55-VP-quality-SER');
    ylabel(axesHandle,'CFO error (Hz)');
    title(axesHandle,sprintf('%s, SNR=-21 dB',caseNames(caseIndex)));
end
xlabel(tiles,'Payload symbol index'); legend(axesHandle,'Location','best');
exportgraphics(figureHandle,fullfile(formalFolder, ...
    'figure_c_minus21db_symbol_cfo_error.png'),'Resolution',180);
close(figureHandle);

figureHandle = figure('Visible','off','Color','w');
tiles = tiledlayout(figureHandle,2,1,'TileSpacing','compact');
for caseIndex = 1:2
    axesHandle = nexttile(tiles); hold(axesHandle,'on'); grid(axesHandle,'on');
    trace = representative{caseIndex};
    stem(axesHandle,layout.midambleAfterDataIndex(1:7), ...
        ones(7,1),'DisplayName','Paper effective Midamble');
    acceptedIndex = find(trace.stage55AcceptedMask);
    stem(axesHandle,acceptedIndex,0.8*ones(size(acceptedIndex)), ...
        'DisplayName','Stage55 accepted VP');
    ylim(axesHandle,[0,1.2]); ylabel(axesHandle,'Pilot event');
    title(axesHandle,sprintf('%s, first paired packet at -21 dB', ...
        caseNames(caseIndex)));
end
xlabel(tiles,'Payload symbol index'); legend(axesHandle,'Location','best');
exportgraphics(figureHandle,fullfile(formalFolder, ...
    'figure_d_pilot_positions_and_coverage.png'),'Resolution',180);
close(figureHandle);

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
