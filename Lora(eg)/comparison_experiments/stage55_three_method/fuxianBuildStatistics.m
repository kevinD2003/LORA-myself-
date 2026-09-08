function statistics = fuxianBuildStatistics( ...
    records,schedule,experiment,options)
%FUXIANBUILDSTATISTICS Region and orbit-window SER/delivered-BER tables.

arguments
    records table
    schedule (1,1) struct
    experiment (1,1) struct
    options.WindowDurationSec (1,1) double {mustBePositive} = 10
end

methods = experiment.methodNames;
snrGrid = unique(records.snrDb,'stable').';
regions = {'high_doppler_rate','high_doppler_shift'};
summaryRows = repmat(localEmptySummary(), ...
    numel(snrGrid)*numel(regions)*numel(methods),1);
rowIndex = 0;
for snrDb = snrGrid
    for regionIndex = 1:numel(regions)
        for methodIndex = 1:numel(methods)
            selected = records.snrDb == snrDb & ...
                strcmp(records.region,regions{regionIndex}) & ...
                strcmp(records.method,methods{methodIndex});
            rowIndex = rowIndex+1;
            summaryRows(rowIndex) = localSummaryRow( ...
                records(selected,:),snrDb,regions{regionIndex}, ...
                methods{methodIndex});
        end
    end
end
summary = struct2table(summaryRows);

windowRows = repmat(localEmptyWindow(),0,1);
windowRowIndex = 0;
referenceMethod = methods{1};
for snrDb = snrGrid
    for regionIndex = 1:numel(regions)
        reference = records(records.snrDb == snrDb & ...
            strcmp(records.region,regions{regionIndex}) & ...
            strcmp(records.method,referenceMethod),:);
        intervals = localRegionIntervals( ...
            unique(reference.frameIndex),schedule);
        windows = localWindows(intervals,options.WindowDurationSec);
        for windowIndex = 1:size(windows,1)
            for methodIndex = 1:numel(methods)
                selected = records.snrDb == snrDb & ...
                    strcmp(records.region,regions{regionIndex}) & ...
                    strcmp(records.method,methods{methodIndex}) & ...
                    records.frameCenterTimeSec >= windows(windowIndex,1) & ...
                    records.frameCenterTimeSec < windows(windowIndex,2);
                if ~any(selected)
                    continue
                end
                windowRowIndex = windowRowIndex+1;
                windowRows(windowRowIndex,1) = localWindowRow( ... %#ok<AGROW>
                    records(selected,:),snrDb,regions{regionIndex}, ...
                    methods{methodIndex},windowIndex, ...
                    windows(windowIndex,1),windows(windowIndex,2));
            end
        end
    end
end
windowStatistics = struct2table(windowRows);
windowStatistics = sortrows(windowStatistics, ...
    {'snrDb','region','windowIndex','method'});

statistics.summary = summary;
statistics.windowStatistics = windowStatistics;
statistics.windowDurationSec = options.WindowDurationSec;
end

function row = localSummaryRow(records,snrDb,region,method)
row = localEmptySummary();
row.snrDb = snrDb;
row.region = {region};
row.method = {method};
row.frameCount = height(records);
row.symbolCount = sum(records.symbolCount);
row.symbolErrors = sum(records.symbolErrors);
row.ser = row.symbolErrors/row.symbolCount;
[row.serShown,row.serLower95,row.serUpper95] = ...
    satelliteFig3BerInterval95(row.symbolErrors,row.symbolCount);
row.bitCount = sum(records.bitCount);
row.deliveredBitErrors = sum(records.deliveredBitErrors);
row.deliveredBer = row.deliveredBitErrors/row.bitCount;
[row.deliveredBerShown,row.deliveredBerLower95, ...
    row.deliveredBerUpper95] = satelliteFig3BerInterval95( ...
    row.deliveredBitErrors,row.bitCount);
row.cfoRmseBins = sqrt(sum(records.cfoSseBins)/ ...
    sum(records.cfoSampleCount));
row.meanAcceptedVirtualPilots = mean( ...
    records.acceptedVirtualPilots);
row.meanExplicitMidambles = mean( ...
    records.explicitMidambleAcceptedCount);
end

function row = localWindowRow( ...
        records,snrDb,region,method,index,startTime,endTime)
row = localEmptyWindow();
row.snrDb = snrDb;
row.region = {region};
row.method = {method};
row.windowIndex = index;
row.windowStartTimeSec = startTime;
row.windowCenterTimeSec = 0.5*(startTime+endTime);
row.windowEndTimeSec = endTime;
row.frameCount = height(records);
row.symbolCount = sum(records.symbolCount);
row.symbolErrors = sum(records.symbolErrors);
row.ser = row.symbolErrors/row.symbolCount;
[row.serShown,row.serLower95,row.serUpper95] = ...
    satelliteFig3BerInterval95(row.symbolErrors,row.symbolCount);
row.bitCount = sum(records.bitCount);
row.deliveredBitErrors = sum(records.deliveredBitErrors);
row.deliveredBer = row.deliveredBitErrors/row.bitCount;
[row.deliveredBerShown,row.deliveredBerLower95, ...
    row.deliveredBerUpper95] = satelliteFig3BerInterval95( ...
    row.deliveredBitErrors,row.bitCount);
end

function intervals = localRegionIntervals(frameIndices,schedule)
mask = false(schedule.frameCount,1);
mask(frameIndices) = true;
starts = find(mask & [true;~mask(1:end-1)]);
ends = find(mask & [~mask(2:end);true]);
intervals = [schedule.frameStartTimeSec(starts), ...
    schedule.frameEndTimeSec(ends)];
end

function windows = localWindows(intervals,duration)
windows = zeros(0,2);
for intervalIndex = 1:size(intervals,1)
    startTime = intervals(intervalIndex,1);
    endTime = intervals(intervalIndex,2);
    edges = (startTime:duration:endTime).';
    if isempty(edges) || edges(end) < endTime
        edges(end+1,1) = endTime; %#ok<AGROW>
    end
    if numel(edges) < 2
        edges = [startTime;endTime];
    end
    windows = [windows;edges(1:end-1),edges(2:end)]; %#ok<AGROW>
end
end

function row = localEmptySummary()
row = struct('snrDb',NaN,'region',{{''}},'method',{{''}}, ...
    'frameCount',0,'symbolCount',0,'symbolErrors',0, ...
    'ser',NaN,'serShown',NaN,'serLower95',NaN,'serUpper95',NaN, ...
    'bitCount',0,'deliveredBitErrors',0,'deliveredBer',NaN, ...
    'deliveredBerShown',NaN,'deliveredBerLower95',NaN, ...
    'deliveredBerUpper95',NaN,'cfoRmseBins',NaN, ...
    'meanAcceptedVirtualPilots',NaN,'meanExplicitMidambles',NaN);
end

function row = localEmptyWindow()
row = struct('snrDb',NaN,'region',{{''}},'method',{{''}}, ...
    'windowIndex',0,'windowStartTimeSec',NaN, ...
    'windowCenterTimeSec',NaN,'windowEndTimeSec',NaN, ...
    'frameCount',0,'symbolCount',0,'symbolErrors',0, ...
    'ser',NaN,'serShown',NaN,'serLower95',NaN,'serUpper95',NaN, ...
    'bitCount',0,'deliveredBitErrors',0,'deliveredBer',NaN, ...
    'deliveredBerShown',NaN,'deliveredBerLower95',NaN, ...
    'deliveredBerUpper95',NaN);
end
