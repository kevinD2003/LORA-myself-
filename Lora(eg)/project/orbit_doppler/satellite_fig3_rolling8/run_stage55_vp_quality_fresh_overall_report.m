function report = run_stage55_vp_quality_fresh_overall_report(options)
%RUN_STAGE55_VP_QUALITY_FRESH_OVERALL_REPORT Fresh Stage55 result suite.
%   Consumes only a newly regenerated paired NoVP/VP-quality experiment
%   and a newly regenerated exact Senior-PREC replay with the same frames.
%   It produces Stage55-like orbit-time figures, a pooled regional summary,
%   and a complexity audit that keeps unlike operation classes separate.

arguments
    options.FreshResultFolder (1,:) char = fullfile(fileparts( ...
        mfilename('fullpath')),'results', ...
        'stage55_vp_quality_fresh_rerun_20260812')
    options.OutputFolderName (1,:) char = ...
        'stage55_vp_quality_fresh_overall_report_20260812'
    options.WindowDurationSec (1,1) double {mustBePositive} = 10
    options.RunRuntimeBenchmark (1,1) logical = true
    options.RuntimeFramesPerSnrRegion (1,1) double ...
        {mustBeInteger,mustBePositive} = 4
    options.ForceRuntimeBenchmark (1,1) logical = false
    options.ReferenceRecordFileName (1,:) char = ...
        'stage55_fresh_senior_prec_records.mat'
    options.ReferenceMethodName (1,:) char = 'Senior-PREC'
    options.ReferenceMethodLabel (1,:) char = 'Senior-PREC (hard)'
    options.ReferenceUsesContinuousPhasePowerCombining (1,1) logical = false
    options.ReferenceUsesMatchedSoftDecode (1,1) logical = false
end

root = fileparts(mfilename('fullpath'));
outputFolder = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(outputFolder), mkdir(outputFolder); end
sourceFile = fullfile(options.FreshResultFolder, ...
    'stage55_vp_mechanism_ablation.mat');
seniorFile = fullfile(options.FreshResultFolder, ...
    options.ReferenceRecordFileName);
if ~isfile(sourceFile) || ~isfile(seniorFile)
    error('SatelliteFig3:FreshOverallInput', ...
        ['The fresh NoVP/VP-quality run and fresh Senior-PREC replay ' ...
        'must both finish before plotting.']);
end
source = load(sourceFile);
senior = load(seniorFile);
localValidateFreshSources(source,senior);
if any(~strcmp(senior.records.method,options.ReferenceMethodName))
    error('SatelliteFig3:FreshOverallReferenceMethod', ...
        'Reference records do not match method %s.', ...
        options.ReferenceMethodName);
end
config = source.config;
schedule = source.schedule;
methodNames = {options.ReferenceMethodName, ...
    'Stage55-NoVP','Stage55-VP-quality'};
methodLabels = {options.ReferenceMethodLabel, ...
    'Stage55-NoVP (ML-soft)','Stage55-VP-quality (ML-soft)'};

records = localUniformRecords(source,senior,methodNames);
localValidateUniformRecords(records,source,methodNames);
summary = localRegionSummary(records,config,schedule, ...
    source.options.SnrGridDb,methodNames);
windowStatistics = localWindowStatistics(records,config,schedule, ...
    source.options.SnrGridDb,methodNames,options.WindowDurationSec);
complexity = localComplexityTable(config,methodNames, ...
    options.ReferenceUsesContinuousPhasePowerCombining, ...
    options.ReferenceUsesMatchedSoftDecode);

runtimeSamples = table();
runtimeSummary = table();
if options.RunRuntimeBenchmark
    timing = run_stage55_three_method_runtime_benchmark( ...
        FreshResultFolder=options.FreshResultFolder, ...
        FramesPerSnrRegion=options.RuntimeFramesPerSnrRegion, ...
        Force=options.ForceRuntimeBenchmark);
    runtimeSamples = timing.samples;
    runtimeSummary = timing.summary;
end

recordCsv = fullfile(outputFolder, ...
    'stage55_fresh_three_method_frame_records.csv');
summaryCsv = fullfile(outputFolder, ...
    'stage55_fresh_three_method_region_summary.csv');
windowCsv = fullfile(outputFolder, ...
    'stage55_fresh_three_method_window_statistics.csv');
complexityCsv = fullfile(outputFolder, ...
    'stage55_fresh_three_method_analytical_complexity.csv');
runtimeSampleCsv = fullfile(outputFolder, ...
    'stage55_fresh_three_method_runtime_samples.csv');
runtimeSummaryCsv = fullfile(outputFolder, ...
    'stage55_fresh_three_method_runtime_summary.csv');
writetable(records,recordCsv);
writetable(summary,summaryCsv);
writetable(windowStatistics,windowCsv);
writetable(complexity,complexityCsv);
if ~isempty(runtimeSamples)
    writetable(runtimeSamples,runtimeSampleCsv);
    writetable(runtimeSummary,runtimeSummaryCsv);
end

overallFigure = localPlotOverall(outputFolder,summary, ...
    source.options.SnrGridDb,methodNames,methodLabels,source.options);
complexityFigure = localPlotComplexity(outputFolder,complexity, ...
    runtimeSummary,methodNames,methodLabels,schedule.frameDurationSec);
regionFigures = cell(0,1);
regionKeys = {'high_doppler_rate','high_doppler_shift'};
for snrIndex = 1:numel(source.options.SnrGridDb)
    for regionIndex = 1:numel(regionKeys)
        figureRecord = localPlotOrbitRegion(outputFolder, ...
            windowStatistics,records,config,schedule, ...
            source.options.SnrGridDb(snrIndex), ...
            regionKeys{regionIndex},methodNames,methodLabels, ...
            source.options);
        regionFigures{end+1,1} = figureRecord; %#ok<AGROW>
    end
end

markdownFile = fullfile(outputFolder, ...
    'STAGE55_FRESH_THREE_METHOD_REPORT.md');
localWriteMarkdown(markdownFile,summary,complexity,runtimeSummary, ...
    source.options,options,methodNames,config,schedule);
matFile = fullfile(outputFolder, ...
    'stage55_fresh_three_method_overall_report.mat');
freshSourceFile = sourceFile;
freshSeniorFile = seniorFile;
freshReferenceFile = seniorFile;
save(matFile,'config','schedule','records','summary', ...
    'windowStatistics','complexity','runtimeSamples','runtimeSummary', ...
    'overallFigure','complexityFigure','regionFigures','options', ...
    'freshSourceFile','freshSeniorFile','freshReferenceFile');

report = struct('outputFolder',outputFolder,'records',records, ...
    'summary',summary,'windowStatistics',windowStatistics, ...
    'complexity',complexity,'runtimeSamples',runtimeSamples, ...
    'runtimeSummary',runtimeSummary,'overallFigure',overallFigure, ...
    'complexityFigure',complexityFigure,'regionFigures',{regionFigures}, ...
    'markdownFile',markdownFile,'matFile',matFile);
fprintf('Fresh Stage55 three-method report complete: %s\n',outputFolder);
disp(summary(:,{'snrDb','region','method','ser','hardBer', ...
    'deliveredBer','deliveredPer','cfoRmseBins', ...
    'meanAcceptedVirtualPilots','falseAcceptedVirtualPilots', ...
    'packetGoodputBps'}));
end

function localValidateFreshSources(source,senior)
required = {'config','schedule','segments','options','modes','records'};
for index = 1:numel(required)
    if ~isfield(source,required{index})
        error('SatelliteFig3:FreshOverallStage55Field', ...
            'Fresh Stage55 MAT is missing %s.',required{index});
    end
end
if ~isfield(senior,'config') || ~isfield(senior,'schedule') || ...
        ~isfield(senior,'segments') || ~isfield(senior,'options') || ...
        ~isfield(senior,'records')
    error('SatelliteFig3:FreshOverallSeniorField', ...
        'Fresh Senior-PREC MAT is incomplete.');
end
if ~isequal(source.modes.mode,{'NoVP';'VP-quality'}) || ...
        ~isequal(source.modes.enableVirtualPilots,[false;true]) || ...
        ~isequal(source.modes.qualityAware,[false;true])
    error('SatelliteFig3:FreshOverallModes', ...
        'The fresh Stage55 source is not the strict NoVP/VP-quality pair.');
end
if ~isequaln(source.config,senior.config) || ...
        ~isequaln(source.schedule,senior.schedule) || ...
        ~isequal(source.segments,senior.segments) || ...
        ~isequal(source.options.SnrGridDb,senior.options.SnrGridDb) || ...
        source.options.PassCount ~= senior.options.PassCount || ...
        source.options.PayloadSeedBase ~= senior.options.PayloadSeedBase || ...
        source.options.NoiseSeedBase ~= senior.options.NoiseSeedBase
    error('SatelliteFig3:FreshOverallLedger', ...
        'Fresh Stage55 and Senior-PREC sources do not share one ledger.');
end
if source.options.PayloadSeedBase == 2026550800 || ...
        source.options.NoiseSeedBase == 2026550900
    error('SatelliteFig3:FreshOverallOldSeed', ...
        'The requested report refuses the previous frozen seed pair.');
end
if source.options.PassCount < 2
    warning('SatelliteFig3:FreshOverallPassCount', ...
        'Only one independent pass is present; pass-level CIs are undefined.');
end
end

function records = localUniformRecords(source,senior,methodNames)
noVp = source.records(strcmp(source.records.mode,'NoVP'),:);
quality = source.records(strcmp(source.records.mode,'VP-quality'),:);
noVpTable = localStage55RecordTable(noVp,methodNames{2},source.options);
qualityTable = localStage55RecordTable( ...
    quality,methodNames{3},source.options);
seniorTable = senior.records(:,noVpTable.Properties.VariableNames);
records = [seniorTable;noVpTable;qualityTable];
methodOrder = zeros(height(records),1);
for index = 1:numel(methodNames)
    methodOrder(strcmp(records.method,methodNames{index})) = index;
end
records.methodOrder = methodOrder;
records = sortrows(records,{'snrDb','passIndex','segmentIndex', ...
    'frameIndex','methodOrder'});
records.methodOrder = [];
end

function tableOut = localStage55RecordTable(input,methodName,options)
count = height(input);
payloadSeed = zeros(count,1);
noiseSeed = zeros(count,1);
for row = 1:count
    snrIndex = find(options.SnrGridDb == input.snrDb(row),1);
    payloadSeed(row) = options.PayloadSeedBase+1000000*snrIndex+ ...
        10000*input.passIndex(row)+input.frameIndex(row);
    noiseSeed(row) = options.NoiseSeedBase+1000000*snrIndex+ ...
        10000*input.passIndex(row)+input.frameIndex(row);
end
method = repmat({methodName},count,1);
deliveredBitErrors = input.softBitErrors;
deliveredFrameError = input.softFrameError;
receiverRuntimeSec = nan(count,1);
tableOut = table(input.snrDb,input.passIndex,input.segmentIndex, ...
    input.frameIndex,input.frameCenterTimeSec,input.driftBinsPerFrame, ...
    input.region,method,payloadSeed,noiseSeed,input.symbolCount, ...
    input.symbolErrors,input.bitCount,input.hardBitErrors, ...
    deliveredBitErrors,deliveredFrameError,input.cfoSseBins, ...
    input.cfoSampleCount,input.acceptedVirtualPilots, ...
    input.falseAcceptedVirtualPilots,receiverRuntimeSec, ...
    nan(count,1), ...
    'VariableNames',{'snrDb','passIndex','segmentIndex','frameIndex', ...
    'frameCenterTimeSec','driftBinsPerFrame','region','method', ...
    'payloadSeed','noiseSeed','symbolCount','symbolErrors','bitCount', ...
    'hardBitErrors','deliveredBitErrors','deliveredFrameError', ...
    'cfoSseBins','cfoSampleCount','acceptedVirtualPilots', ...
    'falseAcceptedVirtualPilots','receiverRuntimeSec', ...
    'estimatedFrameCfoBins'});
end

function localValidateUniformRecords(records,source,methodNames)
physicalCount = height(source.records)/2;
if height(records) ~= physicalCount*numel(methodNames)
    error('SatelliteFig3:FreshOverallRecordCount', ...
        'The uniform three-method ledger has an unexpected row count.');
end
reference = sortrows(records(strcmp(records.method,methodNames{1}), ...
    {'snrDb','passIndex','segmentIndex','frameIndex','payloadSeed', ...
    'noiseSeed'}));
for methodIndex = 2:numel(methodNames)
    branch = sortrows(records(strcmp(records.method, ...
        methodNames{methodIndex}),reference.Properties.VariableNames));
    if ~isequal(reference,branch)
        error('SatelliteFig3:FreshOverallUnpaired', ...
            'The three methods were not evaluated on identical fresh frames.');
    end
end
if any(records.symbolCount <= 0) || any(records.bitCount <= 0) || ...
        any(records.symbolErrors > records.symbolCount) || ...
        any(records.hardBitErrors > records.bitCount) || ...
        any(records.deliveredBitErrors > records.bitCount) || ...
        any(records.cfoSampleCount <= 0)
    error('SatelliteFig3:FreshOverallMetricBounds', ...
        'A fresh per-frame metric is outside its physical bounds.');
end
end

function summary = localRegionSummary(records,config,schedule,snrGrid,methods)
regionKeys = {'high_doppler_rate','high_doppler_shift'};
nominalRate = localPayloadBitCount(config)/schedule.frameDurationSec;
rows = repmat(struct(),0,1);
for snrIndex = 1:numel(snrGrid)
    for regionIndex = 1:numel(regionKeys)
        for methodIndex = 1:numel(methods)
            selected = records.snrDb == snrGrid(snrIndex) & ...
                strcmp(records.region,regionKeys{regionIndex}) & ...
                strcmp(records.method,methods{methodIndex});
            if ~any(selected), continue; end
            symbols = sum(records.symbolCount(selected));
            bits = sum(records.bitCount(selected));
            frames = sum(selected);
            cfoSamples = sum(records.cfoSampleCount(selected));
            ser = sum(records.symbolErrors(selected))/symbols;
            hardBer = sum(records.hardBitErrors(selected))/bits;
            deliveredBer = sum(records.deliveredBitErrors(selected))/bits;
            deliveredPer = sum(records.deliveredFrameError(selected))/frames;
            [serShown,~,~] = satelliteFig3BerInterval95( ...
                sum(records.symbolErrors(selected)),symbols);
            [hardShown,~,~] = satelliteFig3BerInterval95( ...
                sum(records.hardBitErrors(selected)),bits);
            [deliveredShown,~,~] = satelliteFig3BerInterval95( ...
                sum(records.deliveredBitErrors(selected)),bits);
            cfo = sqrt(sum(records.cfoSseBins(selected))/cfoSamples);
            row = struct('snrDb',snrGrid(snrIndex), ...
                'region',regionKeys{regionIndex}, ...
                'method',methods{methodIndex},'frameCount',frames, ...
                'symbolCount',symbols,'symbolErrors', ...
                sum(records.symbolErrors(selected)),'ser',ser, ...
                'serShown',serShown,'bitCount',bits, ...
                'hardBitErrors',sum(records.hardBitErrors(selected)), ...
                'hardBer',hardBer,'hardBerShown',hardShown, ...
                'deliveredBitErrors', ...
                sum(records.deliveredBitErrors(selected)), ...
                'deliveredBer',deliveredBer, ...
                'deliveredBerShown',deliveredShown, ...
                'deliveredFrameErrors', ...
                sum(records.deliveredFrameError(selected)), ...
                'deliveredPer',deliveredPer,'cfoRmseBins',cfo, ...
                'meanAcceptedVirtualPilots',mean( ...
                    records.acceptedVirtualPilots(selected)), ...
                'falseAcceptedVirtualPilots',sum( ...
                    records.falseAcceptedVirtualPilots(selected)), ...
                'nominalPayloadRateBps',nominalRate, ...
                'packetGoodputBps',nominalRate*(1-deliveredPer), ...
                'decoder',localDecoder(methods{methodIndex}));
            passStats = localPassStatistics(records,selected,nominalRate);
            fields = fieldnames(passStats);
            for fieldIndex = 1:numel(fields)
                row.(fields{fieldIndex}) = passStats.(fields{fieldIndex});
            end
            if isempty(rows)
                rows = row;
            else
                rows(end+1,1) = row; %#ok<AGROW>
            end
        end
    end
end
summary = struct2table(rows);
end

function output = localPassStatistics(records,selected,nominalRate)
passes = unique(records.passIndex(selected));
metric = nan(numel(passes),5);
for index = 1:numel(passes)
    rows = selected & records.passIndex == passes(index);
    metric(index,1) = sum(records.symbolErrors(rows))/ ...
        sum(records.symbolCount(rows));
    metric(index,2) = sum(records.hardBitErrors(rows))/ ...
        sum(records.bitCount(rows));
    metric(index,3) = sum(records.deliveredBitErrors(rows))/ ...
        sum(records.bitCount(rows));
    metric(index,4) = mean(records.deliveredFrameError(rows));
    metric(index,5) = sqrt(sum(records.cfoSseBins(rows))/ ...
        sum(records.cfoSampleCount(rows)));
end
names = {'ser','hardBer','deliveredBer','deliveredPer','cfoRmseBins'};
output = struct('independentPassCount',numel(passes));
for index = 1:numel(names)
    [meanValue,lower,upper] = localMeanCi95(metric(:,index));
    output.([names{index} 'PassMean']) = meanValue;
    output.([names{index} 'PassCi95Lower']) = lower;
    output.([names{index} 'PassCi95Upper']) = upper;
end
goodput = nominalRate*(1-metric(:,4));
[meanValue,lower,upper] = localMeanCi95(goodput);
output.packetGoodputBpsPassMean = meanValue;
output.packetGoodputBpsPassCi95Lower = lower;
output.packetGoodputBpsPassCi95Upper = upper;
end

function [sampleMean,lower,upper] = localMeanCi95(values)
values = values(:);
sampleMean = mean(values);
if numel(values) < 2
    lower = NaN;
    upper = NaN;
    return
end
critical = localTCritical95(numel(values)-1);
halfWidth = critical*std(values,0)/sqrt(numel(values));
lower = sampleMean-halfWidth;
upper = sampleMean+halfWidth;
end

function critical = localTCritical95(degreesFreedom)
tableValues = [12.7062 4.3027 3.1824 2.7764 2.5706 2.4469 ...
    2.3646 2.3060 2.2622 2.2281 2.2010 2.1788 2.1604 2.1448 ...
    2.1314 2.1199 2.1098 2.1009 2.0930 2.0860 2.0796 2.0739 ...
    2.0687 2.0639 2.0595 2.0555 2.0518 2.0484 2.0452 2.0423];
if degreesFreedom <= numel(tableValues)
    critical = tableValues(degreesFreedom);
else
    critical = 1.96;
end
end

function tableOut = localWindowStatistics(records,config,schedule, ...
        snrGrid,methods,windowDurationSec)
edges = (schedule.passStartTimeSec:windowDurationSec: ...
    schedule.passEndTimeSec).';
if edges(end) < schedule.passEndTimeSec
    edges(end+1,1) = schedule.passEndTimeSec;
else
    edges(end) = schedule.passEndTimeSec;
end
regionKeys = {'high_doppler_rate','high_doppler_shift'};
nominalRate = localPayloadBitCount(config)/schedule.frameDurationSec;
rows = repmat(struct(),0,1);
for snrIndex = 1:numel(snrGrid)
    for regionIndex = 1:numel(regionKeys)
        for windowIndex = 1:numel(edges)-1
            for methodIndex = 1:numel(methods)
                selected = records.snrDb == snrGrid(snrIndex) & ...
                    strcmp(records.region,regionKeys{regionIndex}) & ...
                    strcmp(records.method,methods{methodIndex}) & ...
                    records.frameCenterTimeSec >= edges(windowIndex) & ...
                    records.frameCenterTimeSec < edges(windowIndex+1);
                row = localEmptyWindowRow(snrGrid(snrIndex), ...
                    regionKeys{regionIndex},methods{methodIndex}, ...
                    windowIndex,edges(windowIndex),edges(windowIndex+1));
                if any(selected)
                    row.frameCount = sum(selected);
                    row.symbolCount = sum(records.symbolCount(selected));
                    row.symbolErrors = sum(records.symbolErrors(selected));
                    [row.serShown,row.serLower95,row.serUpper95] = ...
                        satelliteFig3BerInterval95(row.symbolErrors, ...
                        row.symbolCount);
                    row.ser = row.symbolErrors/row.symbolCount;
                    row.bitCount = sum(records.bitCount(selected));
                    row.hardBitErrors = sum(records.hardBitErrors(selected));
                    [row.hardBerShown,row.hardBerLower95, ...
                        row.hardBerUpper95] = satelliteFig3BerInterval95( ...
                        row.hardBitErrors,row.bitCount);
                    row.hardBer = row.hardBitErrors/row.bitCount;
                    row.deliveredBitErrors = sum( ...
                        records.deliveredBitErrors(selected));
                    [row.deliveredBerShown,row.deliveredBerLower95, ...
                        row.deliveredBerUpper95] = ...
                        satelliteFig3BerInterval95( ...
                        row.deliveredBitErrors,row.bitCount);
                    row.deliveredBer = row.deliveredBitErrors/row.bitCount;
                    row.deliveredFrameErrors = sum( ...
                        records.deliveredFrameError(selected));
                    [~,row.deliveredPerLower95,row.deliveredPerUpper95] = ...
                        satelliteFig3BerInterval95( ...
                        row.deliveredFrameErrors,row.frameCount);
                    row.deliveredPer = ...
                        row.deliveredFrameErrors/row.frameCount;
                    row.cfoRmseBins = sqrt(sum( ...
                        records.cfoSseBins(selected))/sum( ...
                        records.cfoSampleCount(selected)));
                    row.meanAcceptedVirtualPilots = mean( ...
                        records.acceptedVirtualPilots(selected));
                    row.packetGoodputBps = nominalRate*(1-row.deliveredPer);
                    row.packetGoodputLower95 = ...
                        nominalRate*(1-row.deliveredPerUpper95);
                    row.packetGoodputUpper95 = ...
                        nominalRate*(1-row.deliveredPerLower95);
                end
                if isempty(rows)
                    rows = row;
                else
                    rows(end+1,1) = row; %#ok<AGROW>
                end
            end
        end
    end
end
tableOut = struct2table(rows);
end

function row = localEmptyWindowRow(snrDb,region,method,index,startTime,endTime)
row = struct('snrDb',snrDb,'region',region,'method',method, ...
    'windowIndex',index,'windowStartTimeSec',startTime, ...
    'windowCenterTimeSec',(startTime+endTime)/2, ...
    'windowEndTimeSec',endTime,'frameCount',0,'symbolCount',0, ...
    'symbolErrors',0,'ser',NaN,'serShown',NaN,'serLower95',NaN, ...
    'serUpper95',NaN,'bitCount',0,'hardBitErrors',0,'hardBer',NaN, ...
    'hardBerShown',NaN,'hardBerLower95',NaN,'hardBerUpper95',NaN, ...
    'deliveredBitErrors',0,'deliveredBer',NaN, ...
    'deliveredBerShown',NaN,'deliveredBerLower95',NaN, ...
    'deliveredBerUpper95',NaN,'deliveredFrameErrors',0, ...
    'deliveredPer',NaN,'deliveredPerLower95',NaN, ...
    'deliveredPerUpper95',NaN,'cfoRmseBins',NaN, ...
    'meanAcceptedVirtualPilots',NaN,'packetGoodputBps',NaN, ...
    'packetGoodputLower95',NaN,'packetGoodputUpper95',NaN);
end

function tableOut = localComplexityTable(config,methods, ...
        referenceUsesPowerCombining,referenceUsesMatchedSoftDecode)
m = config.samplesPerSymbol;
known = config.bootstrapPilotCount;
payload = config.payloadSymbolCount;
frame = config.frameSymbolCount;
etaStepSenior = 0.1;
etaStepStage55 = 0.1; % Wrapper uses the bootstrap function's default.
etaSenior = numel(0:etaStepSenior:(1-etaStepSenior/2));
etaStage55 = numel(0:etaStepStage55:(1-etaStepStage55/2));
if etaSenior ~= 10 || etaStage55 ~= 10
    error('SatelliteFig3:FreshOverallBootstrapGrid', ...
        'Complexity accounting expects both active eta grids to have 10 points.');
end
% A continuous-phase Huang-PREC reference power-combines all known
% preambles over the eta grid and performs one diagnostic FFT per preamble.
% The archival paper-code path averages first and uses only etaSenior FFTs.
if referenceUsesPowerCombining
    seniorBootstrap = known*etaSenior+known;
else
    seniorBootstrap = etaSenior;
end
stage55Bootstrap = known*etaStage55+known;
minimumIterations = 2;
maximumIterations = config.maxSenLoRaIterations;
fftPerIteration = payload+frame;
llrPerIteration = payload*config.sf*m;
blockLength = 4+config.cr;
blockCount = payload/blockLength;
hammingPerIteration = blockCount*config.sf*16*blockLength;
causalCandidates = payload-blockLength;
maximumResidualBanks = causalCandidates*max(0,maximumIterations-2);

method = methods(:);
preambleEtaGridStepBins = [etaStepSenior;etaStepStage55;etaStepStage55];
preambleEtaCandidateCount = [etaSenior;etaStage55;etaStage55];
preambleKnownUpchirpCount = repmat(known,3,1);
preambleLengthMfftCount = [seniorBootstrap;stage55Bootstrap;stage55Bootstrap];
iterationLowerBound = [1;minimumIterations;minimumIterations];
iterationUpperBound = [1;minimumIterations;maximumIterations];
payloadTrackerMfftPerIteration = [payload;payload;payload];
referenceConfidenceMfft = frame*double(referenceUsesMatchedSoftDecode);
confidenceMfftPerIteration = [referenceConfidenceMfft;frame;frame];
totalLengthMfftLower = [seniorBootstrap+payload+referenceConfidenceMfft; ...
    stage55Bootstrap+minimumIterations*fftPerIteration; ...
    stage55Bootstrap+minimumIterations*fftPerIteration];
totalLengthMfftUpper = [seniorBootstrap+payload+referenceConfidenceMfft; ...
    stage55Bootstrap+minimumIterations*fftPerIteration; ...
    stage55Bootstrap+maximumIterations*fftPerIteration];
normalizedMfftLoadLower = totalLengthMfftLower/totalLengthMfftLower(1);
normalizedMfftLoadUpper = totalLengthMfftUpper/totalLengthMfftLower(1);
referenceLlrInputs = llrPerIteration*double(referenceUsesMatchedSoftDecode);
llrLogSumExpInputsLower = [referenceLlrInputs;minimumIterations*llrPerIteration; ...
    minimumIterations*llrPerIteration];
llrLogSumExpInputsUpper = [referenceLlrInputs;minimumIterations*llrPerIteration; ...
    maximumIterations*llrPerIteration];
referenceHammingTerms = hammingPerIteration*double( ...
    referenceUsesMatchedSoftDecode);
softHammingScoreTermsLower = [referenceHammingTerms; ...
    minimumIterations*hammingPerIteration; ...
    minimumIterations*hammingPerIteration];
softHammingScoreTermsUpper = [referenceHammingTerms; ...
    minimumIterations*hammingPerIteration; ...
    maximumIterations*hammingPerIteration];
residualOffsetCandidateCount = [0;0;numel(config.residualSearchBins)];
residualProjectionBanksLower = [0;0;0];
residualProjectionBanksUpper = [0;0;maximumResidualBanks];
crossFramePreambleHistoryLength = [0;config.virtualPilotHistoryLength; ...
    config.virtualPilotHistoryLength];
payloadVirtualPilotsEnabled = [false;false;true];
if referenceUsesPowerCombining
    referenceCountText = ...
        'exact: 8x10 eta FFTs, 8 diagnostics, 112 payload FFTs';
else
    referenceCountText = 'exact: 10 eta FFTs plus 112 payload FFTs';
end
if referenceUsesMatchedSoftDecode
    referenceCountText = [referenceCountText, ...
        ', plus one common ML-soft confidence pass'];
end
countInterpretation = { ...
    referenceCountText; ...
    'exact: common Stage55 bootstrap and exactly two NoVP iterations'; ...
    'code-derived 2-to-5 iteration bound; actual early stopping is data dependent'};
if referenceUsesPowerCombining
    referenceOrder = ...
        'O((Np*Keta+Np+Npayload)*M*log2(M))';
else
    referenceOrder = 'O((Keta+Npayload)*M*log2(M))';
end
asymptoticOrder = { ...
    referenceOrder; ...
    'O(Np*Keta*M*log2(M)+I*((Npayload+Nframe)*M*log2(M)+Npayload*SF*M))'; ...
    'NoVP order plus causal VP residual/phase/rate scalar updates'};
tableOut = table(method,payloadVirtualPilotsEnabled, ...
    preambleEtaGridStepBins,preambleEtaCandidateCount, ...
    preambleKnownUpchirpCount,preambleLengthMfftCount, ...
    iterationLowerBound,iterationUpperBound, ...
    payloadTrackerMfftPerIteration,confidenceMfftPerIteration, ...
    totalLengthMfftLower,totalLengthMfftUpper, ...
    normalizedMfftLoadLower,normalizedMfftLoadUpper, ...
    llrLogSumExpInputsLower,llrLogSumExpInputsUpper, ...
    softHammingScoreTermsLower,softHammingScoreTermsUpper, ...
    residualOffsetCandidateCount,residualProjectionBanksLower, ...
    residualProjectionBanksUpper,crossFramePreambleHistoryLength, ...
    countInterpretation,asymptoticOrder);
end

function record = localPlotOverall(folder,summary,snrGrid,methods,labels,runOptions)
regionKeys = {'high_doppler_rate','high_doppler_shift'};
groupLabels = cell(numel(snrGrid)*2,1);
metrics = {'serShown','hardBerShown','deliveredBerShown', ...
    'deliveredPer','cfoRmseBins','packetGoodputBps'};
metricData = cell(numel(metrics),1);
for index = 1:numel(metrics)
    metricData{index} = nan(numel(groupLabels),numel(methods));
end
row = 0;
for snrIndex = 1:numel(snrGrid)
    for regionIndex = 1:numel(regionKeys)
        row = row+1;
        if regionIndex == 1, regionShort = 'high rate'; else, regionShort = 'high shift'; end
        groupLabels{row} = sprintf('%g dB / %s',snrGrid(snrIndex),regionShort);
        for methodIndex = 1:numel(methods)
            selected = summary.snrDb == snrGrid(snrIndex) & ...
                strcmp(summary.region,regionKeys{regionIndex}) & ...
                strcmp(summary.method,methods{methodIndex});
            for metricIndex = 1:numel(metrics)
                metricData{metricIndex}(row,methodIndex) = ...
                    summary.(metrics{metricIndex})(selected);
            end
        end
    end
end

fig = figure('Visible','off','Color','w','Position',[50 30 1780 1060]);
layout = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
titles = {'(a) LoRa symbol error rate', ...
    '(b) Hard-output BER (decoder-fair)', ...
    '(c) Delivered BER', '(d) Delivered PER', ...
    '(e) CFO tracking RMSE','(f) Packet goodput'};
ylabels = {'SER','Hard BER','Delivered BER','PER', ...
    'CFO RMSE (bin)','Goodput (bit/s)'};
colors = localMethodColors();
for metricIndex = 1:numel(metrics)
    ax = nexttile(layout);
    localGroupedBars(ax,metricData{metricIndex},colors,labels);
    set(ax,'XTick',1:numel(groupLabels),'XTickLabel',groupLabels, ...
        'XTickLabelRotation',16);
    ylabel(ax,ylabels{metricIndex});
    title(ax,titles{metricIndex},'FontWeight','normal');
    grid(ax,'on'); box(ax,'on');
    if ismember(metricIndex,[1 2 3 5])
        set(ax,'YScale','log');
    elseif metricIndex == 4
        ylim(ax,[0 1.03]);
    end
    if metricIndex == 1
        legend(ax,labels,'Location','northoutside','NumColumns',3, ...
            'Box','off','FontSize',8);
    end
end
sgtitle(layout,sprintf([ ...
    'Fresh Stage55 three-method results: %d independent passes; ' ...
    'payload/noise seeds %d / %d'],runOptions.PassCount, ...
    runOptions.PayloadSeedBase,runOptions.NoiseSeedBase), ...
    'FontWeight','normal','FontSize',14);
pngFile = fullfile(folder,'stage55_fresh_three_method_overall_summary.png');
pdfFile = fullfile(folder,'stage55_fresh_three_method_overall_summary.pdf');
figFile = fullfile(folder,'stage55_fresh_three_method_overall_summary.fig');
exportgraphics(fig,pngFile,'Resolution',220);
exportgraphics(fig,pdfFile,'ContentType','vector');
savefig(fig,figFile);
close(fig);
record = struct('pngFile',pngFile,'pdfFile',pdfFile,'figFile',figFile);
end

function record = localPlotComplexity(folder,complexity,runtime,methods,labels,frameDuration)
colors = localMethodColors();
fig = figure('Visible','off','Color','w','Position',[70 40 1700 1020]);
layout = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');

ax = nexttile(layout);
localBoundBars(ax,complexity.totalLengthMfftLower, ...
    complexity.totalLengthMfftUpper,colors,labels);
ylabel(ax,'Length-M FFTs / frame'); title(ax,'(a) FFT count');

ax = nexttile(layout);
localBoundBars(ax,complexity.normalizedMfftLoadLower, ...
    complexity.normalizedMfftLoadUpper,colors,labels);
    ylabel(ax,sprintf('Relative to %s',methods{1}));
    title(ax,'(b) Normalized FFT load');

ax = nexttile(layout);
localBoundBars(ax,complexity.llrLogSumExpInputsLower/1e6, ...
    complexity.llrLogSumExpInputsUpper/1e6,colors,labels);
ylabel(ax,'Inputs / frame (million)'); title(ax,'(c) LLR log-sum-exp inputs');

ax = nexttile(layout);
localBoundBars(ax,complexity.softHammingScoreTermsLower/1e3, ...
    complexity.softHammingScoreTermsUpper/1e3,colors,labels);
ylabel(ax,'Terms / frame (thousand)'); title(ax,'(d) Soft-Hamming score terms');

ax = nexttile(layout);
localBoundBars(ax,complexity.residualProjectionBanksLower, ...
    complexity.residualProjectionBanksUpper,colors,labels);
ylabel(ax,'Projection banks / frame');
title(ax,'(e) VP residual-search banks (upper bound)');

ax = nexttile(layout);
if isempty(runtime)
    axis(ax,'off');
    text(ax,0.5,0.5,'Empirical runtime benchmark disabled', ...
        'HorizontalAlignment','center');
else
    ordered = localOrderRows(runtime,methods);
    b = bar(ax,[ordered.medianRuntimeSec ordered.p95RuntimeSec], ...
        'grouped');
    b(1).FaceColor = [0.25 0.55 0.85];
    b(2).FaceColor = [0.90 0.45 0.15];
    set(ax,'XTick',1:numel(labels),'XTickLabel',labels, ...
        'XTickLabelRotation',16);
    yline(ax,frameDuration,'k:','frame duration', ...
        'LabelHorizontalAlignment','left');
    ylabel(ax,'Receiver time / frame (s)');
    title(ax,'(f) Fresh-frame MATLAB timing (supplemental)');
    legend(ax,{'median','95th percentile'},'Location','northwest', ...
        'Box','off');
    grid(ax,'on'); box(ax,'on');
end
sgtitle(layout,[ ...
    'Complexity audit: unlike operations are reported separately; ' ...
    'error bars denote code-level lower/upper bounds'], ...
    'FontWeight','normal','FontSize',14);
pngFile = fullfile(folder,'stage55_fresh_three_method_complexity.png');
pdfFile = fullfile(folder,'stage55_fresh_three_method_complexity.pdf');
figFile = fullfile(folder,'stage55_fresh_three_method_complexity.fig');
exportgraphics(fig,pngFile,'Resolution',220);
exportgraphics(fig,pdfFile,'ContentType','vector');
savefig(fig,figFile);
close(fig);
record = struct('pngFile',pngFile,'pdfFile',pdfFile,'figFile',figFile);
end

function record = localPlotOrbitRegion(folder,windowTable,records,config, ...
        schedule,snrDb,regionKey,methods,labels,runOptions)
colors = localMethodColors();
styles = {'s--','d-.','o-'};
fig = figure('Visible','off','Color','w','Position',[40 15 1860 1960]);
layout = tiledlayout(fig,8,1,'TileSpacing','compact','Padding','compact');
selectedRegion = records.snrDb == snrDb & ...
    strcmp(records.region,regionKey) & strcmp(records.method,methods{1});
targetIntervals = localRegionIntervals( ...
    unique(records.frameIndex(selectedRegion)),schedule);

denseTime = linspace(schedule.passStartTimeSec, ...
    schedule.passEndTimeSec,1600).';
trajectory = satelliteFig3Trajectory(denseTime,config);
ax1 = nexttile(layout);
hold(ax1,'on');
plot(ax1,denseTime,trajectory.dopplerShiftHz/1e3, ...
    'Color',[0 0.45 0.74],'LineWidth',1.5);
ylabel(ax1,'Shift (kHz)'); ylim(ax1,[-20 20]);
grid(ax1,'on');
title(ax1,localRegionTitle(regionKey,records,selectedRegion,config), ...
    'FontWeight','normal');
localBlindLines(ax1,schedule.window); localTargetLines(ax1,targetIntervals);

ax2 = nexttile(layout); hold(ax2,'on');
plot(ax2,denseTime,trajectory.dopplerRateHzPerSec, ...
    'Color',[0.85 0.33 0.10],'LineWidth',1.5);
ylabel(ax2,'Rate (Hz/s)'); ylim(ax2,[-250 0]); grid(ax2,'on');
title(ax2,'Orbit Doppler-rate trajectory','FontWeight','normal');
localBlindLines(ax2,schedule.window); localTargetLines(ax2,targetIntervals);

plotSpecs = { ...
    'serShown','serLower95','serUpper95','Window SER',[1e-5 1],true; ...
    'deliveredBerShown','deliveredBerLower95','deliveredBerUpper95', ...
        'Window delivered BER',[1e-6 1],true; ...
    'deliveredPer','deliveredPerLower95','deliveredPerUpper95', ...
        'Window delivered PER',[0 1.03],false};
axesList = [ax1 ax2];
for panel = 1:3
    ax = nexttile(layout); hold(ax,'on');
    if plotSpecs{panel,6}, set(ax,'YScale','log'); end
    for methodIndex = 1:numel(methods)
        rows = localWindowRows(windowTable,snrDb,regionKey,methods{methodIndex});
        lower = rows.(plotSpecs{panel,2});
        if plotSpecs{panel,6}, lower = max(lower,plotSpecs{panel,5}(1)); end
        localBand(ax,rows.windowCenterTimeSec,lower, ...
            rows.(plotSpecs{panel,3}),colors(methodIndex,:));
    end
    for methodIndex = 1:numel(methods)
        rows = localWindowRows(windowTable,snrDb,regionKey,methods{methodIndex});
        plot(ax,rows.windowCenterTimeSec,rows.(plotSpecs{panel,1}), ...
            styles{methodIndex},'Color',colors(methodIndex,:), ...
            'LineWidth',1.35,'MarkerSize',4, ...
            'DisplayName',labels{methodIndex});
    end
    ylabel(ax,plotSpecs{panel,4}); ylim(ax,plotSpecs{panel,5});
    grid(ax,'on'); grid(ax,'minor'); box(ax,'on');
    localShadeBlind(ax,schedule.window); localTargetLines(ax,targetIntervals);
    if panel == 1
        legend(ax,'Location','best','FontSize',8,'Box','on');
    end
    axesList(end+1) = ax; %#ok<AGROW>
end

ax6 = nexttile(layout); hold(ax6,'on'); set(ax6,'YScale','log');
cfoValues = [];
for methodIndex = 1:numel(methods)
    rows = localWindowRows(windowTable,snrDb,regionKey,methods{methodIndex});
    plot(ax6,rows.windowCenterTimeSec,rows.cfoRmseBins, ...
        styles{methodIndex},'Color',colors(methodIndex,:), ...
        'LineWidth',1.35,'MarkerSize',4,'DisplayName',labels{methodIndex});
    cfoValues = [cfoValues;rows.cfoRmseBins]; %#ok<AGROW>
end
finiteCfo = cfoValues(isfinite(cfoValues) & cfoValues > 0);
if ~isempty(finiteCfo)
    ylim(ax6,[max(1e-3,min(finiteCfo)/1.8),max(finiteCfo)*1.8]);
end
ylabel(ax6,'CFO RMSE (bin)');
grid(ax6,'on'); grid(ax6,'minor'); box(ax6,'on');
legend(ax6,'Location','best','FontSize',8,'Box','on');
localShadeBlind(ax6,schedule.window); localTargetLines(ax6,targetIntervals);
axesList(end+1) = ax6;

ax7 = nexttile(layout); hold(ax7,'on');
qualityRows = localWindowRows(windowTable,snrDb,regionKey,methods{3});
plot(ax7,qualityRows.windowCenterTimeSec, ...
    qualityRows.meanAcceptedVirtualPilots,'b:','LineWidth',1.2, ...
    'DisplayName','Accepted quality VPs');
ylabel(ax7,'Accepted VPs/frame'); ylim(ax7,[0 12]);
grid(ax7,'on'); grid(ax7,'minor'); box(ax7,'on');
legend(ax7,'Location','best','FontSize',8,'Box','on');
localShadeBlind(ax7,schedule.window); localTargetLines(ax7,targetIntervals);
axesList(end+1) = ax7;

ax8 = nexttile(layout); hold(ax8,'on');
for methodIndex = 1:numel(methods)
    rows = localWindowRows(windowTable,snrDb,regionKey,methods{methodIndex});
    localBand(ax8,rows.windowCenterTimeSec,rows.packetGoodputLower95, ...
        rows.packetGoodputUpper95,colors(methodIndex,:));
    plot(ax8,rows.windowCenterTimeSec,rows.packetGoodputBps, ...
        styles{methodIndex},'Color',colors(methodIndex,:), ...
        'LineWidth',1.35,'MarkerSize',4,'DisplayName',labels{methodIndex});
end
nominal = localPayloadBitCount(config)/schedule.frameDurationSec;
yline(ax8,nominal,'k:','nominal','HandleVisibility','off');
ylabel(ax8,'Packet goodput (bit/s)');
xlabel(ax8,'Time relative to closest approach (s)');
ylim(ax8,[0 1.06*nominal]); grid(ax8,'on'); grid(ax8,'minor'); box(ax8,'on');
localShadeBlind(ax8,schedule.window); localTargetLines(ax8,targetIntervals);
axesList(end+1) = ax8;

for index = 1:numel(axesList)
    xlim(axesList(index),[schedule.passStartTimeSec schedule.passEndTimeSec]);
    set(axesList(index),'FontName','Times New Roman','FontSize',9, ...
        'GridLineStyle',':','MinorGridLineStyle',':');
end
sgtitle(layout,sprintf([ ...
    'Fresh Stage55-like orbit result: %.1f dB, %s, %d passes, ' ...
    'seeds %d/%d'],snrDb,strrep(regionKey,'_',' '), ...
    runOptions.PassCount,runOptions.PayloadSeedBase, ...
    runOptions.NoiseSeedBase),'FontWeight','normal','FontSize',14);
base = sprintf('stage55_fresh_%s_%s_dB',regionKey,localSnrToken(snrDb));
pngFile = fullfile(folder,[base '.png']);
pdfFile = fullfile(folder,[base '.pdf']);
figFile = fullfile(folder,[base '.fig']);
exportgraphics(fig,pngFile,'Resolution',220);
exportgraphics(fig,pdfFile,'ContentType','vector');
savefig(fig,figFile);
close(fig);
record = struct('snrDb',snrDb,'region',regionKey, ...
    'pngFile',pngFile,'pdfFile',pdfFile,'figFile',figFile);
end

function rows = localWindowRows(tableIn,snrDb,region,method)
rows = tableIn(tableIn.snrDb == snrDb & strcmp(tableIn.region,region) & ...
    strcmp(tableIn.method,method),:);
rows = sortrows(rows,'windowIndex');
end

function titleText = localRegionTitle(regionKey,records,selected,config)
trajectory = satelliteFig3Trajectory(records.frameCenterTimeSec(selected),config);
if strcmp(regionKey,'high_doppler_rate')
    titleText = sprintf([ ...
        'High Doppler-rate region: |rate| %.1f--%.1f Hz/s; ' ...
        'payload drift >= 0.5 bin/frame'], ...
        min(abs(trajectory.dopplerRateHzPerSec)), ...
        max(abs(trajectory.dopplerRateHzPerSec)));
else
    titleText = sprintf([ ...
        'High Doppler-shift region: |shift| %.1f--%.1f kHz; ' ...
        'payload drift < 0.5 bin/frame'], ...
        min(abs(trajectory.dopplerShiftHz))/1e3, ...
        max(abs(trajectory.dopplerShiftHz))/1e3);
end
end

function localGroupedBars(ax,data,colors,labels)
b = bar(ax,data,'grouped');
for index = 1:numel(b)
    b(index).FaceColor = colors(index,:);
    b(index).DisplayName = labels{index};
end
end

function localBoundBars(ax,lower,upper,colors,labels)
x = (1:numel(lower)).';
b = bar(ax,x,lower,'FaceColor','flat');
b.CData = colors;
hold(ax,'on');
errorbar(ax,x,lower,zeros(size(lower)),upper-lower,'k.', ...
    'LineWidth',1.4,'CapSize',10);
set(ax,'XTick',x,'XTickLabel',labels,'XTickLabelRotation',16);
grid(ax,'on'); box(ax,'on');
end

function ordered = localOrderRows(tableIn,methods)
order = zeros(numel(methods),1);
for index = 1:numel(methods)
    selected = find(strcmp(tableIn.method,methods{index}));
    if numel(selected) ~= 1
        error('SatelliteFig3:FreshOverallMethodOrder', ...
            'Expected exactly one table row for method %s.',methods{index});
    end
    order(index) = selected;
end
ordered = tableIn(order,:);
end

function colors = localMethodColors()
colors = [0.84 0.18 0.13;0.35 0.35 0.35;0.00 0.38 0.78];
end

function intervals = localRegionIntervals(frameIndices,schedule)
mask = false(schedule.frameCount,1);
mask(frameIndices) = true;
starts = find(mask & [true;~mask(1:end-1)]);
ends = find(mask & [~mask(2:end);true]);
intervals = [schedule.frameStartTimeSec(starts), ...
    schedule.frameEndTimeSec(ends)];
end

function localBand(ax,x,lower,upper,color)
valid = isfinite(x) & isfinite(lower) & isfinite(upper) & upper >= lower;
starts = find(valid & [true;~valid(1:end-1)]);
ends = find(valid & [~valid(2:end);true]);
for segment = 1:numel(starts)
    index = starts(segment):ends(segment);
    patch(ax,[x(index);flipud(x(index))], ...
        [lower(index);flipud(upper(index))],color, ...
        'FaceAlpha',0.07,'EdgeColor','none','HandleVisibility','off');
end
end

function localShadeBlind(ax,window)
hold(ax,'on');
limits = ylim(ax);
blind = window.blindIntervalSec;
patch(ax,[blind(1) blind(2) blind(2) blind(1)], ...
    [limits(1) limits(1) limits(2) limits(2)],[0.88 0.88 0.88], ...
    'FaceAlpha',0.25,'EdgeColor','none','HandleVisibility','off');
localBlindLines(ax,window);
ylim(ax,limits);
end

function localBlindLines(ax,window)
xline(ax,window.blindIntervalSec(1),'Color',[0.45 0.45 0.45], ...
    'LineStyle',':','HandleVisibility','off');
xline(ax,window.blindIntervalSec(2),'Color',[0.45 0.45 0.45], ...
    'LineStyle',':','HandleVisibility','off');
end

function localTargetLines(ax,intervals)
for index = 1:size(intervals,1)
    xline(ax,intervals(index,1),'Color',[0.20 0.55 0.20], ...
        'LineStyle','--','LineWidth',0.7,'HandleVisibility','off');
    xline(ax,intervals(index,2),'Color',[0.20 0.55 0.20], ...
        'LineStyle','--','LineWidth',0.7,'HandleVisibility','off');
end
end

function decoder = localDecoder(method)
if strcmp(method,'Senior-PREC')
    decoder = 'hard Hamming';
else
    decoder = 'ML-soft Hamming';
end
end

function token = localSnrToken(snrDb)
token = strrep(sprintf('%g',snrDb),'-','minus');
end

function bitCount = localPayloadBitCount(config)
blockLength = 4+config.cr;
blockCount = config.payloadSymbolCount/blockLength;
bitCount = blockCount*4*config.sf;
end

function localWriteMarkdown(file,summary,complexity,runtime,runOptions, ...
        reportOptions,methods,config,schedule)
fid = fopen(file,'w');
if fid < 0
    error('SatelliteFig3:FreshOverallMarkdown', ...
        'Cannot write %s.',file);
end
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'# Stage55 改进后项目：全新重跑三方法结果\n\n');
fprintf(fid,['本报告不读取旧的冻结性能数据。NoVP、VP-quality 和 %s ' ...
    '均使用本轮重新生成的同一批载荷、噪声与连续相位波形。\n\n'], ...
    methods{1});
fprintf(fid,'- SNR：%s dB\n',mat2str(runOptions.SnrGridDb(:).'));
fprintf(fid,'- 独立遍历次数：%d\n',runOptions.PassCount);
fprintf(fid,'- 载荷种子基数：%d\n',runOptions.PayloadSeedBase);
fprintf(fid,'- 噪声种子基数：%d\n',runOptions.NoiseSeedBase);
fprintf(fid,'- 每帧有效载荷：%d bit；帧时长 %.6f s\n\n', ...
    localPayloadBitCount(config),schedule.frameDurationSec);
fprintf(fid,['`Stage55-NoVP` 与 `Stage55-VP-quality` 的唯一处理变量是是否允许' ...
    '可靠载荷判决进入虚拟导频跟踪。两者都使用 ML-soft Hamming 输出。']);
if reportOptions.ReferenceUsesContinuousPhasePowerCombining
    fprintf(fid,['`%s` 按黄鹏论文式 (4-1)--(4-7) 搜索 eta/CFO，' ...
        '为与 Stage55 的连续相位波形公平比较，对各前导 FFT 功率求和，' ...
        '且载荷期 CFO 保持冻结。'],methods{1});
else
    fprintf(fid,'`%s` 使用师兄原始的一帧一次前导 CFO。',methods{1});
end
if reportOptions.ReferenceUsesMatchedSoftDecode
    fprintf(fid,['三路 delivered BER 均使用同一 ML-soft Hamming 引擎；' ...
        'hard BER 是不含软译码差异的主公平指标。\n\n']);
else
    fprintf(fid,['参考支路使用硬 Hamming，因此 delivered BER/PER 还包含译码器差异；' ...
        '请同时查看 hard BER。\n\n']);
end
fprintf(fid,'## 区域汇总\n\n');
fprintf(fid,['| SNR | 区域 | 方法 | SER | Hard BER | Delivered BER | PER | ' ...
    'CFO RMSE/bin | VP/帧 | 误接纳 VP | Goodput bit/s |\n']);
fprintf(fid,'|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for row = 1:height(summary)
    fprintf(fid,['| %.0f | %s | %s | %.6g | %.6g | %.6g | %.6g | ' ...
        '%.6g | %.3f | %d | %.3f |\n'],summary.snrDb(row), ...
        summary.region{row},summary.method{row},summary.ser(row), ...
        summary.hardBer(row),summary.deliveredBer(row), ...
        summary.deliveredPer(row),summary.cfoRmseBins(row), ...
        summary.meanAcceptedVirtualPilots(row), ...
        summary.falseAcceptedVirtualPilots(row), ...
        summary.packetGoodputBps(row));
end
fprintf(fid,'\n## 理论复杂度\n\n');
fprintf(fid,['不同种类的运算没有被强行合并成一个分数。FFT、LLR 输入、软汉明' ...
    '评分项和虚拟导频残差投影分别列出。\n\n']);
fprintf(fid,['| 方法 | M点FFT/帧 | LLR输入/帧 | 软汉明项/帧 | ' ...
    'VP残差投影组/帧 |\n']);
fprintf(fid,'|---|---:|---:|---:|---:|\n');
for row = 1:height(complexity)
    fprintf(fid,'| %s | %g--%g | %g--%g | %g--%g | %g--%g |\n', ...
        complexity.method{row},complexity.totalLengthMfftLower(row), ...
        complexity.totalLengthMfftUpper(row), ...
        complexity.llrLogSumExpInputsLower(row), ...
        complexity.llrLogSumExpInputsUpper(row), ...
        complexity.softHammingScoreTermsLower(row), ...
        complexity.softHammingScoreTermsUpper(row), ...
        complexity.residualProjectionBanksLower(row), ...
        complexity.residualProjectionBanksUpper(row));
end
if ~isempty(runtime)
    fprintf(fid,'\n## 本机 MATLAB 耗时（补充指标）\n\n');
    fprintf(fid,'接收机计时不含波形生成；这不是硬件无关的理论复杂度。\n\n');
    fprintf(fid,'| 方法 | 样本 | 中位数 s | P95 s | 相对师兄中位数 |\n');
    fprintf(fid,'|---|---:|---:|---:|---:|\n');
    ordered = localOrderRows(runtime,methods);
    for row = 1:height(ordered)
        fprintf(fid,'| %s | %d | %.6g | %.6g | %.3f |\n', ...
            ordered.method{row},ordered.sampleCount(row), ...
            ordered.medianRuntimeSec(row),ordered.p95RuntimeSec(row), ...
            ordered.ratioToSeniorMedian(row));
    end
end
end
