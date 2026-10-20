function layout = v4BuildFrameLayout(config)
%V4BUILDFRAMELAYOUT Common bootstrap/data/Midamble physical timeline.

nData = config.payloadSymbolCount;
nMidamble = config.paperMidambleCount;
midambleAfter = (config.paperMidambleInterval:config.paperMidambleInterval:nData-1).';
kind = strings(config.commonTimelineSymbolCount,1);
dataIndex = nan(config.commonTimelineSymbolCount,1);
bootstrapRows = (1:config.bootstrapPilotCount).';
kind(bootstrapRows) = "bootstrap";
row = config.bootstrapPilotCount;
dataRows = zeros(nData,1);
midambleRows = zeros(nMidamble,1);
midambleIndex = 0;
for data = 1:nData
    row = row+1;
    kind(row) = "data";
    dataIndex(row) = data;
    dataRows(data) = row;
    if any(midambleAfter == data)
        row = row+1;
        midambleIndex = midambleIndex+1;
        kind(row) = "midamble";
        midambleRows(midambleIndex) = row;
    end
end
if row ~= config.commonTimelineSymbolCount || midambleIndex ~= nMidamble
    error('V4:FrameLayout','Common frame layout count mismatch.');
end
physicalStartTimeSec = (0:row-1).'*config.symbolDurationSec;
layout = struct('kind',kind,'dataIndex',dataIndex, ...
    'bootstrapRows',bootstrapRows,'dataRows',dataRows, ...
    'midambleRows',midambleRows,'midambleAfterDataIndex',midambleAfter, ...
    'physicalStartTimeSec',physicalStartTimeSec, ...
    'physicalCenterTimeSec',physicalStartTimeSec+config.symbolDurationSec/2, ...
    'dataStartTimeSec',physicalStartTimeSec(dataRows), ...
    'physicalSymbolCount',row);
end
