function layout = buildFrameLayout(cfg)
%BUILDFRAMELAYOUT Build Point and Midamble-Point timing from locked values.

arguments
    cfg (1,1) struct
end

symbolDurationS = cfg.radio.symbolDurationS;
payloadStartS = (cfg.frame.preambleUpchirps + ...
    cfg.frame.completeDownchirps + ...
    cfg.frame.synchronizationFractionalChirps)*symbolDurationS;
initialDownchirpStartS = (cfg.frame.preambleUpchirps + ...
    cfg.frame.completeDownchirps - 1)*symbolDurationS;

payloadSymbols = cfg.frame.payloadSymbols;
layout.pointDataStartS = payloadStartS + ...
    (0:payloadSymbols-1)*symbolDurationS;

maxSlots = payloadSymbols + ceil(payloadSymbols/ ...
    cfg.frame.midambleSpacingDataSymbols);
slotKind = strings(1, maxSlots);
slotStartS = nan(1, maxSlots);
slotDataIndex = nan(1, maxSlots);
slotCount = 0;
physicalSlot = 0;
for dataIndex = 1:payloadSymbols
    slotCount = slotCount + 1;
    slotKind(slotCount) = "data";
    slotStartS(slotCount) = payloadStartS + physicalSlot*symbolDurationS;
    slotDataIndex(slotCount) = dataIndex;
    physicalSlot = physicalSlot + 1;
    completedBlock = mod(dataIndex, ...
        cfg.frame.midambleSpacingDataSymbols) == 0;
    dataRemain = dataIndex < payloadSymbols;
    atPayloadEnd = dataIndex == payloadSymbols;
    shouldInsert = (completedBlock && dataRemain) || ...
        (atPayloadEnd && cfg.frame.insertAfterFinalPartialBlock);
    if shouldInsert
        slotCount = slotCount + 1;
        slotKind(slotCount) = "midamble";
        slotStartS(slotCount) = payloadStartS + ...
            physicalSlot*symbolDurationS;
        physicalSlot = physicalSlot + 1;
    end
end

layout.slotKind = slotKind(1:slotCount);
layout.slotStartS = slotStartS(1:slotCount);
layout.slotDataIndex = slotDataIndex(1:slotCount);
layout.midambleDataStartS = layout.slotStartS( ...
    layout.slotKind == "data");
layout.midambleStartS = layout.slotStartS( ...
    layout.slotKind == "midamble");
layout.payloadStartS = payloadStartS;
layout.initialDownchirpStartS = initialDownchirpStartS;
layout.payloadSymbols = payloadSymbols;
layout.numberOfMidambles = numel(layout.midambleStartS);
layout.pointToaS = payloadStartS + ...
    payloadSymbols*symbolDurationS;
layout.midamblePointToaS = payloadStartS + ...
    slotCount*symbolDurationS;
end
