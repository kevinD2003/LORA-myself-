function layout = sf12BuildFrameLayout(cfg)
%SF12BUILDFRAMELAYOUT Build the common 23-data plus 8-midamble frame.

nData = cfg.frame.payloadSymbolCount;
nMidamble = cfg.frame.toaMidambleCount;
kind = strings(nData+nMidamble,1);
dataIndex = nan(nData+nMidamble,1);
row = 0;
dataRows = zeros(nData,1);
midambleRows = zeros(nMidamble,1);
midambleAfter = [3:3:21,nData].';
midambleIndex = 0;
for k = 1:nData
    row = row+1;
    kind(row) = "data";
    dataIndex(row) = k;
    dataRows(k) = row;
    if any(midambleAfter == k)
        row = row+1;
        midambleIndex = midambleIndex+1;
        kind(row) = "midamble";
        midambleRows(midambleIndex) = row;
    end
end
assert(row == nData+nMidamble && midambleIndex == nMidamble);

ts = cfg.radio.symbolDurationSec;
payloadStart = (cfg.frame.preambleUpchirps+cfg.frame.completeDownchirps+ ...
    cfg.frame.synchronizationFractionalChirps)*ts;
layout.kind = kind;
layout.dataIndex = dataIndex;
layout.dataRows = dataRows;
layout.midambleRows = midambleRows;
layout.trackingMidambleRows = midambleRows(1:cfg.frame.trackingMidambleCount);
layout.terminalMidambleRow = midambleRows(end);
layout.midambleAfterDataIndex = midambleAfter;
layout.physicalStartTimeSec = payloadStart+(0:row-1).'*ts;
layout.dataStartTimeSec = layout.physicalStartTimeSec(dataRows);
layout.initialDownchirpStartTimeSec = ...
    (cfg.frame.preambleUpchirps+cfg.frame.completeDownchirps-1)*ts;
layout.payloadStartTimeSec = payloadStart;
layout.paperNativeToaSec = payloadStart+row*ts;
layout.stage55NativeToaSec = payloadStart+nData*ts;
layout.physicalSymbolCount = row;
end
