function schedule = v4BuildTrackASchedule(config)
%V4BUILDTRACKASCHEDULE 8U+2down+0.25down+(DDD M)x7+DD+terminal M.
m = config.samplesPerSymbol;
kind = [repmat("up",8,1);repmat("down",2,1);"quarter-down"];
dataIndex = nan(11,1); midambleIndex = nan(11,1); sampleCount = [repmat(m,10,1);m/4];
midambleAfter = [3 6 9 12 15 18 21 23];
midamble = 0;
for data = 1:23
    kind(end+1,1) = "data"; %#ok<AGROW>
    dataIndex(end+1,1) = data; %#ok<AGROW>
    midambleIndex(end+1,1) = NaN; %#ok<AGROW>
    sampleCount(end+1,1) = m; %#ok<AGROW>
    if any(midambleAfter == data)
        midamble = midamble+1;
        kind(end+1,1) = "midamble"; %#ok<AGROW>
        dataIndex(end+1,1) = NaN; %#ok<AGROW>
        midambleIndex(end+1,1) = midamble; %#ok<AGROW>
        sampleCount(end+1,1) = m; %#ok<AGROW>
    end
end
startSample = [0;cumsum(sampleCount(1:end-1))];
dataRows = find(kind == "data");
midambleRows = find(kind == "midamble");
schedule = struct('kind',kind,'dataIndex',dataIndex,'midambleIndex',midambleIndex, ...
    'sampleCount',sampleCount,'startSample',startSample,'dataRows',dataRows, ...
    'midambleRows',midambleRows,'pointDownRow',10,'quarterDownRow',11, ...
    'midambleAfterDataIndex',midambleAfter(:),'terminalMidambleRow',midambleRows(end), ...
    'totalSamples',sum(sampleCount),'totalSymbols',sum(sampleCount)/m, ...
    'durationSec',sum(sampleCount)/config.sampleRateHz, ...
    'centerTimeOffsetSec',(startSample+sampleCount/2)/config.sampleRateHz);
end
