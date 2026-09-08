function layout = fuxianMidambleLayout(payloadBins, experiment)
%FUXIANMIDAMBLELAYOUT Insert known pilots while retaining all payload data.

config = experiment.config;
payloadBins = payloadBins(:);
if numel(payloadBins) ~= config.payloadSymbolCount
    error('FuxianDuibi:PayloadCount', ...
        'Expected %d payload symbols.', config.payloadSymbolCount);
end

physicalCount = experiment.physicalConfig.frameSymbolCount;
physicalBins = zeros(physicalCount,1);
bootstrapRows = (1:config.bootstrapPilotCount).';
dataRows = zeros(config.payloadSymbolCount,1);
midambleRows = zeros(experiment.midambleCount,1);
trackingMidambleRows = zeros(experiment.trackingMidambleCount,1);
physicalRow = config.bootstrapPilotCount;
midambleIndex = 0;
for dataIndex = 1:config.payloadSymbolCount
    physicalRow = physicalRow + 1;
    dataRows(dataIndex) = physicalRow;
    physicalBins(physicalRow) = payloadBins(dataIndex);
    insertPilot = mod(dataIndex,experiment.midambleSpacing) == 0 && ...
        dataIndex < config.payloadSymbolCount;
    if insertPilot
        physicalRow = physicalRow + 1;
        midambleIndex = midambleIndex + 1;
        midambleRows(midambleIndex) = physicalRow;
        trackingMidambleRows(midambleIndex) = physicalRow;
        physicalBins(physicalRow) = experiment.midambleWaveformBin;
    end
end
terminalMidambleRows = zeros(0,1);
if experiment.includeTerminalMidamble
    physicalRow = physicalRow + 1;
    midambleIndex = midambleIndex + 1;
    midambleRows(midambleIndex) = physicalRow;
    physicalBins(physicalRow) = experiment.midambleWaveformBin;
    terminalMidambleRows = physicalRow;
end
if physicalRow ~= physicalCount || midambleIndex ~= experiment.midambleCount
    error('FuxianDuibi:LayoutCount', ...
        'The physical midamble layout is inconsistent.');
end

layout.physicalBins = physicalBins;
layout.bootstrapRows = bootstrapRows;
layout.dataRows = dataRows;
layout.midambleRows = midambleRows;
layout.trackingMidambleRows = trackingMidambleRows;
layout.terminalMidambleRows = terminalMidambleRows;
layout.compactRows = [bootstrapRows;dataRows];
layout.trackingMidambleAfterDataIndex = ...
    (experiment.midambleSpacing:experiment.midambleSpacing: ...
    config.payloadSymbolCount-1).';
layout.midambleAfterDataIndex = ...
    layout.trackingMidambleAfterDataIndex;
if experiment.includeTerminalMidamble
    layout.midambleAfterDataIndex = [ ...
        layout.midambleAfterDataIndex;config.payloadSymbolCount];
end
layout.physicalSymbolCount = physicalCount;
layout.dataSymbolCount = config.payloadSymbolCount;
layout.midambleCount = experiment.midambleCount;
layout.trackingMidambleCount = experiment.trackingMidambleCount;
layout.toaMidambleCount = experiment.toaMidambleCount;
layout.terminalMidambleCount = experiment.terminalMidambleCount;
layout.frameOverheadFraction = ...
    experiment.midambleCount/(config.frameSymbolCount);
end
