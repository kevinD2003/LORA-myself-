function report = run_stage55_corrected_orbit_region_figures(options)
%RUN_STAGE55_CORRECTED_ORBIT_REGION_FIGURES Stage-55 orbit-time figures.
%   Reconstructs the Huang-PREC-static-CP branch with the exact payload,
%   noise, phase-continuity schedule, and seeds used by the frozen Stage-55
%   corrected SenLoRa validation.  It then draws MATLAB-native five-panel
%   time figures for the high-Doppler-rate and high-Doppler-shift regions.
%   The delivered SenLoRa metric is the final ML-soft Hamming payload.

arguments
    options.SnrGridDb (:,1) double = [-21;-20]
    options.WindowDurationSec (1,1) double {mustBePositive} = 10
    options.OutputFolderName (1,:) char = ...
        'stage55_corrected_orbit_region_figures'
    options.RecomputeHuang (1,1) logical = false
    options.ProgressEveryFrames (1,1) double = 100
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config();
schedule = satelliteFig3ContinuousPassSchedule(config);
regionKeys = {'high_doppler_rate','high_doppler_shift'};

pairedTables = cell(numel(options.SnrGridDb),1);
windowTables = cell(numel(options.SnrGridDb)*numel(regionKeys),1);
figureRecords = cell(numel(options.SnrGridDb)*numel(regionKeys),1);
tableIndex = 0;
for snrIndex = 1:numel(options.SnrGridDb)
    snrDb = options.SnrGridDb(snrIndex);
    sourceDir = localStage55SourceDir(root,snrDb);
    sourceFile = fullfile(sourceDir,'stage55_corrected_validation.mat');
    source = load(sourceFile,'config','options','schedule','segments', ...
        'records','summary');
    localValidateSource(source,config,schedule,snrDb);

    cacheFile = fullfile(resultDir,sprintf( ...
        'stage55_paired_frame_records_%s_dB.csv',localSnrToken(snrDb)));
    if isfile(cacheFile) && ~options.RecomputeHuang
        paired = readtable(cacheFile);
        localValidatePairedCache(paired,source.records,snrDb);
        fprintf('Reusing paired Huang cache: %s\n',cacheFile);
    else
        paired = localReconstructPairedFrames(source,config,schedule, ...
            snrDb,options.ProgressEveryFrames);
        writetable(paired,cacheFile);
    end
    localValidateFrozenSenMetrics(paired,source.summary,snrDb);
    pairedTables{snrIndex} = paired;

    for regionIndex = 1:numel(regionKeys)
        regionKey = regionKeys{regionIndex};
        [windowTable,plotData] = localWindowStatistics( ...
            paired,config,schedule,snrDb,regionKey, ...
            options.WindowDurationSec);
        tableIndex = tableIndex+1;
        windowTables{tableIndex} = windowTable;
        figureRecords{tableIndex} = localPlotRegion( ...
            resultDir,config,schedule,snrDb,regionKey,plotData);
    end
end

windowTable = vertcat(windowTables{:});
windowCsv = fullfile(resultDir, ...
    'stage55_corrected_orbit_window_statistics.csv');
writetable(windowTable,windowCsv);
regionSummary = localRegionSummary(pairedTables,config,schedule);
regionSummaryCsv = fullfile(resultDir, ...
    'stage55_corrected_orbit_region_summary.csv');
writetable(regionSummary,regionSummaryCsv);
save(fullfile(resultDir,'stage55_corrected_orbit_region_figures.mat'), ...
    'config','schedule','options','pairedTables','windowTable', ...
    'regionSummary','figureRecords');
report = struct('resultDir',resultDir,'pairedTables',{pairedTables}, ...
    'windowTable',windowTable,'figures',{figureRecords}, ...
    'windowCsv',windowCsv,'regionSummary',regionSummary, ...
    'regionSummaryCsv',regionSummaryCsv);
fprintf('Stage55 corrected regional orbit figures: %s\n',resultDir);
end

function summary = localRegionSummary(pairedTables,config,schedule)
regionKeys = {'high_doppler_rate','high_doppler_shift'};
rowCount = numel(pairedTables)*numel(regionKeys);
snrDb = nan(rowCount,1);
region = cell(rowCount,1);
frameCount = nan(rowCount,1);
staticBer = nan(rowCount,1);
senSoftBer = nan(rowCount,1);
staticPer = nan(rowCount,1);
senSoftPer = nan(rowCount,1);
staticCfoRmseBins = nan(rowCount,1);
senCfoRmseBins = nan(rowCount,1);
meanSenAcceptedPilots = nan(rowCount,1);
staticGoodputBps = nan(rowCount,1);
senGoodputBps = nan(rowCount,1);
nominal = localPayloadBitCount(config)/schedule.frameDurationSec;
row = 0;
for snrIndex = 1:numel(pairedTables)
    paired = pairedTables{snrIndex};
    for regionIndex = 1:numel(regionKeys)
        row = row+1;
        selected = strcmp(paired.region, ...
            localRecordRegion(regionKeys{regionIndex}));
        frames = sum(selected);
        bits = sum(paired.bitCount(selected));
        samples = sum(paired.cfoSampleCount(selected));
        staticFrameErrors = sum(paired.staticFrameError(selected));
        senFrameErrors = sum(paired.senSoftFrameError(selected));
        snrDb(row) = paired.snrDb(find(selected,1));
        region{row} = regionKeys{regionIndex};
        frameCount(row) = frames;
        staticBer(row) = sum(paired.staticBitErrors(selected))/bits;
        senSoftBer(row) = sum(paired.senSoftBitErrors(selected))/bits;
        staticPer(row) = staticFrameErrors/frames;
        senSoftPer(row) = senFrameErrors/frames;
        staticCfoRmseBins(row) = sqrt( ...
            sum(paired.staticCfoSseBins(selected))/samples);
        senCfoRmseBins(row) = sqrt( ...
            sum(paired.senCfoSseBins(selected))/samples);
        meanSenAcceptedPilots(row) = ...
            mean(paired.senAcceptedPilots(selected));
        staticGoodputBps(row) = nominal*(1-staticPer(row));
        senGoodputBps(row) = nominal*(1-senSoftPer(row));
    end
end
summary = table(snrDb,region,frameCount,staticBer,senSoftBer, ...
    staticPer,senSoftPer,staticCfoRmseBins,senCfoRmseBins, ...
    meanSenAcceptedPilots,staticGoodputBps,senGoodputBps);
end

function sourceDir = localStage55SourceDir(root,snrDb)
if snrDb == -20
    folder = 'stage55_corrected_minus20_full_pass_vp_coverage';
elseif snrDb == -21
    folder = 'stage55_corrected_minus21_full_pass_rate_bound';
else
    error('SatelliteFig3:Stage55RegionSnr', ...
        'Only the frozen -21 and -20 dB Stage-55 runs are available.');
end
sourceDir = fullfile(root,'results',folder);
end

function localValidateSource(source,config,schedule,snrDb)
required = {'config','options','schedule','segments','records','summary'};
for index = 1:numel(required)
    if ~isfield(source,required{index})
        error('SatelliteFig3:Stage55RegionSource', ...
            'Frozen Stage-55 source is missing %s.',required{index});
    end
end
if ~isequaln(source.config,config) || ...
        source.schedule.frameCount ~= schedule.frameCount || ...
        numel(source.options.SnrGridDb) ~= 1 || ...
        source.options.SnrGridDb ~= snrDb || ...
        source.options.PassCount ~= 1
    error('SatelliteFig3:Stage55RegionSourceMismatch', ...
        'Frozen Stage-55 source does not match this plot request.');
end
if any(source.records.snrDb ~= snrDb) || ...
        any(source.records.minimumActiveHistoryCount ~= ...
        config.virtualPilotHistoryLength) || ...
        any(source.records.falseAcceptedPilots ~= 0)
    error('SatelliteFig3:Stage55RegionFrozenMetric', ...
        'Frozen Stage-55 receiver invariants are not satisfied.');
end
end

function paired = localReconstructPairedFrames( ...
        source,config,schedule,snrDb,progressEvery)
sen = sortrows(source.records,{'segmentIndex','frameIndex'});
rowCount = height(sen);
rowForFrame = zeros(schedule.frameCount,1);
if numel(unique(sen.frameIndex)) ~= rowCount
    error('SatelliteFig3:Stage55RegionDuplicateFrame', ...
        'The single-pass Stage-55 source must contain one row per frame.');
end
rowForFrame(sen.frameIndex) = (1:rowCount).';

payloadSeed = nan(rowCount,1);
noiseSeed = nan(rowCount,1);
staticBitErrors = nan(rowCount,1);
staticFrameError = false(rowCount,1);
staticCfoSseBins = nan(rowCount,1);
processed = false(rowCount,1);
known = zeros(config.bootstrapPilotCount,1);
payloadRows = (config.bootstrapPilotCount+1:config.frameSymbolCount).';
completed = 0;
for segmentIndex = 1:size(source.segments,1)
    phaseStateRad = 0;
    for frameIndex = source.segments(segmentIndex,1): ...
            source.segments(segmentIndex,2)
        row = rowForFrame(frameIndex);
        if row == 0 || sen.segmentIndex(row) ~= segmentIndex
            error('SatelliteFig3:Stage55RegionFrameLedger', ...
                'Frozen Stage-55 frame ledger is not reproducible.');
        end
        payloadSeed(row) = source.options.PayloadSeedBase+ ...
            1000000+10000+frameIndex;
        noiseSeed(row) = source.options.NoiseSeedBase+ ...
            1000000+10000+frameIndex;
        payload = satelliteFig3GeneratePayload(config,payloadSeed(row));
        labels = [known;payload.symbolBins];
        [rx,~,truth] = generateContinuousSatelliteFrame( ...
            labels,config, ...
            StartTimeSec=schedule.frameStartTimeSec(frameIndex), ...
            SampleSnrDb=snrDb,NoiseSeed=noiseSeed(row), ...
            InitialPhaseRad=phaseStateRad,NextSymbolBin=0);
        phaseStateRad = localWrapToPi(truth.nextFrameStartPhaseRad);

        static = satelliteFig3HuangPrecStaticCpDecode(rx,config,known);
        referenceBits = payload.dataBits(:);
        staticBits = static.decodedDataBits(:);
        if numel(referenceBits) ~= sen.bitCount(row) || ...
                numel(staticBits) ~= sen.bitCount(row)
            error('SatelliteFig3:Stage55RegionBitCount', ...
                'Reconstructed frame has an unexpected payload length.');
        end
        staticBitErrors(row) = sum(staticBits ~= referenceBits);
        staticFrameError(row) = staticBitErrors(row) > 0;
        truthCfoBins = truth.trueDopplerHz(payloadRows)/ ...
            config.fftBinSpacingHz;
        residual = static.tracker.predictedCfoBins(payloadRows)- ...
            truthCfoBins;
        staticCfoSseBins(row) = sum(residual.^2);
        processed(row) = true;
        completed = completed+1;
        if isfinite(progressEvery) && progressEvery > 0 && ...
                mod(completed,progressEvery) == 0
            fprintf('Paired Huang reconstruction %.1f dB: %d/%d frames.\n', ...
                snrDb,completed,rowCount);
        end
    end
end
if any(~processed)
    error('SatelliteFig3:Stage55RegionIncomplete', ...
        'Not every frozen Stage-55 frame was reconstructed.');
end

frameTimeSec = schedule.frameCenterTimeSec(sen.frameIndex);
paired = table(sen.snrDb,sen.passIndex,sen.segmentIndex,sen.frameIndex, ...
    sen.region,frameTimeSec,payloadSeed,noiseSeed,sen.bitCount, ...
    staticBitErrors,sen.softBitErrors,staticFrameError, ...
    sen.softBitErrors > 0,staticCfoSseBins,sen.cfoSseBins, ...
    sen.cfoSampleCount,sen.acceptedPilots,sen.falseAcceptedPilots, ...
    'VariableNames',{'snrDb','passIndex','segmentIndex','frameIndex', ...
    'region','frameTimeSec','payloadSeed','noiseSeed','bitCount', ...
    'staticBitErrors','senSoftBitErrors','staticFrameError', ...
    'senSoftFrameError','staticCfoSseBins','senCfoSseBins', ...
    'cfoSampleCount','senAcceptedPilots','senFalseAcceptedPilots'});
end

function localValidatePairedCache(paired,sen,snrDb)
required = {'snrDb','frameIndex','staticBitErrors','senSoftBitErrors', ...
    'staticCfoSseBins','senCfoSseBins','senAcceptedPilots'};
if ~all(ismember(required,paired.Properties.VariableNames)) || ...
        height(paired) ~= height(sen) || any(paired.snrDb ~= snrDb) || ...
        ~isequal(paired.frameIndex,sort(sen.frameIndex))
    error('SatelliteFig3:Stage55RegionCache', ...
        'The cached paired frame table does not match the frozen source.');
end
end

function localValidateFrozenSenMetrics(paired,summary,snrDb)
row = find(summary.snrDb == snrDb,1);
if isempty(row)
    error('SatelliteFig3:Stage55RegionSummary', ...
        'Frozen summary does not contain the requested SNR.');
end
bits = sum(paired.bitCount);
softErrors = sum(paired.senSoftBitErrors);
cfoRmse = sqrt(sum(paired.senCfoSseBins)/sum(paired.cfoSampleCount));
accepted = mean(paired.senAcceptedPilots);
if bits ~= summary.bitCount(row) || ...
        softErrors ~= summary.softBitErrors(row) || ...
        abs(softErrors/bits-summary.softBer(row)) > 10*eps || ...
        abs(cfoRmse-summary.cfoRmseBins(row)) > 1e-12 || ...
        abs(accepted-summary.acceptedPilotsPerFrame(row)) > 1e-12 || ...
        any(paired.senFalseAcceptedPilots ~= 0)
    error('SatelliteFig3:Stage55RegionMetricMismatch', ...
        'Paired table does not reproduce the frozen Stage-55 metrics.');
end
end

function [tableOut,data] = localWindowStatistics( ...
        paired,config,schedule,snrDb,regionKey,windowDurationSec)
edges = (schedule.passStartTimeSec:windowDurationSec: ...
    schedule.passEndTimeSec).';
if edges(end) < schedule.passEndTimeSec
    edges(end+1,1) = schedule.passEndTimeSec;
else
    edges(end) = schedule.passEndTimeSec;
end
windowStart = edges(1:end-1);
windowEnd = edges(2:end);
time = (windowStart+windowEnd)/2;
windowCount = numel(time);
trajectory = satelliteFig3Trajectory(time,config);
regionLabel = localRecordRegion(regionKey);
isRegion = strcmp(paired.region,regionLabel);

data = struct( ...
    'timeSec',time, ...
    'trueDopplerHz',trajectory.dopplerShiftHz, ...
    'trueDopplerRateHzPerSec',trajectory.dopplerRateHzPerSec, ...
    'berShown',nan(windowCount,2), ...
    'berRaw',nan(windowCount,2), ...
    'berLower95',nan(windowCount,2), ...
    'berUpper95',nan(windowCount,2), ...
    'perRaw',nan(windowCount,2), ...
    'perLower95',nan(windowCount,2), ...
    'perUpper95',nan(windowCount,2), ...
    'cfoRmseBins',nan(windowCount,2), ...
    'goodputBps',nan(windowCount,2), ...
    'goodputLower95',nan(windowCount,2), ...
    'goodputUpper95',nan(windowCount,2), ...
    'meanAcceptedPilots',nan(windowCount,1), ...
    'frameCount',zeros(windowCount,1), ...
    'targetIntervalsSec',localRegionIntervals( ...
        paired.frameIndex(isRegion),schedule), ...
    'regionKey',regionKey);

nominalRate = localPayloadBitCount(config)/schedule.frameDurationSec;
for windowIndex = 1:windowCount
    selected = isRegion & paired.frameTimeSec >= windowStart(windowIndex) & ...
        paired.frameTimeSec < windowEnd(windowIndex);
    frameCount = sum(selected);
    if frameCount == 0, continue; end
    data.frameCount(windowIndex) = frameCount;
    bits = sum(paired.bitCount(selected));
    sampleCount = sum(paired.cfoSampleCount(selected));
    bitErrors = [sum(paired.staticBitErrors(selected)), ...
        sum(paired.senSoftBitErrors(selected))];
    frameErrors = [sum(paired.staticFrameError(selected)), ...
        sum(paired.senSoftFrameError(selected))];
    cfoSse = [sum(paired.staticCfoSseBins(selected)), ...
        sum(paired.senCfoSseBins(selected))];
    for method = 1:2
        [shown,lower,upper] = satelliteFig3BerInterval95( ...
            bitErrors(method),bits);
        [~,perLower,perUpper] = satelliteFig3BerInterval95( ...
            frameErrors(method),frameCount);
        perRaw = frameErrors(method)/frameCount;
        data.berShown(windowIndex,method) = shown;
        data.berRaw(windowIndex,method) = bitErrors(method)/bits;
        data.berLower95(windowIndex,method) = lower;
        data.berUpper95(windowIndex,method) = upper;
        data.perRaw(windowIndex,method) = perRaw;
        data.perLower95(windowIndex,method) = perLower;
        data.perUpper95(windowIndex,method) = perUpper;
        data.cfoRmseBins(windowIndex,method) = ...
            sqrt(cfoSse(method)/sampleCount);
        data.goodputBps(windowIndex,method) = nominalRate*(1-perRaw);
        data.goodputLower95(windowIndex,method) = ...
            nominalRate*(1-perUpper);
        data.goodputUpper95(windowIndex,method) = ...
            nominalRate*(1-perLower);
    end
    data.meanAcceptedPilots(windowIndex) = ...
        mean(paired.senAcceptedPilots(selected));
end

tableOut = table(repmat(snrDb,windowCount,1), ...
    repmat({regionKey},windowCount,1),(1:windowCount).', ...
    windowStart,time,windowEnd,data.frameCount, ...
    data.berRaw(:,1),data.berRaw(:,2),data.berShown(:,1), ...
    data.berShown(:,2),data.berLower95(:,1),data.berLower95(:,2), ...
    data.berUpper95(:,1),data.berUpper95(:,2), ...
    data.perRaw(:,1),data.perRaw(:,2),data.perLower95(:,1), ...
    data.perLower95(:,2),data.perUpper95(:,1),data.perUpper95(:,2), ...
    data.cfoRmseBins(:,1),data.cfoRmseBins(:,2), ...
    data.meanAcceptedPilots,data.goodputBps(:,1),data.goodputBps(:,2), ...
    data.goodputLower95(:,1),data.goodputLower95(:,2), ...
    data.goodputUpper95(:,1),data.goodputUpper95(:,2), ...
    'VariableNames',{'snrDb','region','windowIndex','windowStartTimeSec', ...
    'windowCenterTimeSec','windowEndTimeSec','frameCount', ...
    'staticBerRaw','senSoftBerRaw','staticBerShown','senSoftBerShown', ...
    'staticBerLower95','senSoftBerLower95','staticBerUpper95', ...
    'senSoftBerUpper95','staticPer','senSoftPer','staticPerLower95', ...
    'senSoftPerLower95','staticPerUpper95','senSoftPerUpper95', ...
    'staticCfoRmseBins','senCfoRmseBins','meanSenAcceptedPilots', ...
    'staticGoodputBps','senGoodputBps','staticGoodputLower95', ...
    'senGoodputLower95','staticGoodputUpper95','senGoodputUpper95'});
tableOut = tableOut(tableOut.frameCount > 0,:);
end

function record = localPlotRegion( ...
        resultDir,config,schedule,snrDb,regionKey,data)
methodNames = {'Huang-PREC-static-CP', ...
    'SenLoRa-VP (Stage55 ML-soft)'};
colors = [0.85 0.15 0.10;0.00 0.35 0.85];
styles = {'s--','o-'};
fig = figure('Visible','off','Color','w','Position',[45 20 1840 1330]);
layout = tiledlayout(fig,5,1,'TileSpacing','compact','Padding','compact');

denseTime = linspace(schedule.passStartTimeSec, ...
    schedule.passEndTimeSec,1200).';
denseTrajectory = satelliteFig3Trajectory(denseTime,config);
ax1 = nexttile(layout);
yyaxis(ax1,'left');
plot(ax1,denseTime,denseTrajectory.dopplerShiftHz/1e3, ...
    'Color',[0 0.45 0.74],'LineWidth',1.65);
ylabel(ax1,'Shift (kHz)'); ylim(ax1,[-20 20]);
yyaxis(ax1,'right');
plot(ax1,denseTime,denseTrajectory.dopplerRateHzPerSec, ...
    'Color',[0.85 0.33 0.10],'LineWidth',1.65);
ylabel(ax1,'Rate (Hz/s)'); ylim(ax1,[-250 0]);
grid(ax1,'on'); grid(ax1,'minor');
title(ax1,localRegionTitle(regionKey,data,config,schedule), ...
    'FontWeight','normal');
localTargetLines(ax1,data.targetIntervalsSec);
localBlindLines(ax1,schedule.window);

ax2 = nexttile(layout); hold(ax2,'on'); set(ax2,'YScale','log');
for method = 1:2
    localBand(ax2,data.timeSec,max(data.berLower95(:,method),1e-7), ...
        data.berUpper95(:,method),colors(method,:));
end
for method = 1:2
    semilogy(ax2,data.timeSec,data.berShown(:,method),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.45,'MarkerSize',5, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
end
grid(ax2,'on'); grid(ax2,'minor'); ylim(ax2,[1e-5 1]);
ylabel(ax2,'Window BER');
legend(ax2,'Location','best','FontSize',8,'Box','on');
localShadeBlind(ax2,schedule.window);
localTargetLines(ax2,data.targetIntervalsSec);

ax3 = nexttile(layout); hold(ax3,'on');
for method = 1:2
    localBand(ax3,data.timeSec,data.perLower95(:,method), ...
        data.perUpper95(:,method),colors(method,:));
end
for method = 1:2
    plot(ax3,data.timeSec,data.perRaw(:,method),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.45,'MarkerSize',5, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
end
grid(ax3,'on'); grid(ax3,'minor'); ylim(ax3,[-0.03 1.03]);
ylabel(ax3,'Window PER');
legend(ax3,'Location','best','FontSize',8,'Box','on');
localShadeBlind(ax3,schedule.window);
localTargetLines(ax3,data.targetIntervalsSec);

ax4 = nexttile(layout);
yyaxis(ax4,'left'); hold(ax4,'on'); set(ax4,'YScale','log');
for method = 1:2
    semilogy(ax4,data.timeSec,data.cfoRmseBins(:,method),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.45,'MarkerSize',5, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
end
ylabel(ax4,'CFO RMSE (bin)'); ylim(ax4,[0.03 1.2]);
yyaxis(ax4,'right');
plot(ax4,data.timeSec,data.meanAcceptedPilots,'b:', ...
    'LineWidth',1.2,'DisplayName','SenLoRa accepted pilots');
ylabel(ax4,'Accepted pilots/frame'); ylim(ax4,[0 10]);
grid(ax4,'on'); grid(ax4,'minor');
legend(ax4,'Location','best','FontSize',8,'Box','on');
localBlindLines(ax4,schedule.window);
localTargetLines(ax4,data.targetIntervalsSec);

ax5 = nexttile(layout); hold(ax5,'on');
for method = 1:2
    localBand(ax5,data.timeSec,data.goodputLower95(:,method), ...
        data.goodputUpper95(:,method),colors(method,:));
end
for method = 1:2
    plot(ax5,data.timeSec,data.goodputBps(:,method),styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.45,'MarkerSize',5, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
end
nominal = localPayloadBitCount(config)/schedule.frameDurationSec;
yline(ax5,nominal,'k:','Nominal 716.1 bit/s', ...
    'HandleVisibility','off','LabelHorizontalAlignment','right');
grid(ax5,'on'); grid(ax5,'minor'); ylim(ax5,[0 1.08*nominal]);
ylabel(ax5,'Goodput (bit/s)');
xlabel(ax5,'Time relative to closest pass point (s)');
legend(ax5,'Location','best','FontSize',8,'Box','on');
localShadeBlind(ax5,schedule.window);
localTargetLines(ax5,data.targetIntervalsSec);

axesList = [ax1 ax2 ax3 ax4 ax5];
for index = 1:numel(axesList)
    ax = axesList(index);
    xlim(ax,[schedule.passStartTimeSec schedule.passEndTimeSec]);
    set(ax,'FontName','Times New Roman','FontSize',10,'Box','on', ...
        'GridLineStyle',':','MinorGridLineStyle',':');
end
sgtitle(layout,sprintf([ ...
    'Stage 55 corrected regional comparison: %.1f dB, 1 complete pass, ' ...
    'single-pass Wilson 95%% (BER/PER)'],snrDb), ...
    'FontName','Times New Roman','FontWeight','normal','FontSize',14);

base = sprintf('stage55_corrected_%s_%s_dB', ...
    regionKey,localSnrToken(snrDb));
pngFile = fullfile(resultDir,[base '.png']);
pdfFile = fullfile(resultDir,[base '.pdf']);
figFile = fullfile(resultDir,[base '.fig']);
drawnow;
exportgraphics(fig,pngFile,'Resolution',220);
exportgraphics(fig,pdfFile,'ContentType','vector');
savefig(fig,figFile);
close(fig);
record = struct('snrDb',snrDb,'regionKey',regionKey, ...
    'pngFile',pngFile,'pdfFile',pdfFile,'figFile',figFile);
fprintf('Created %s\n',pngFile);
end

function titleText = localRegionTitle(regionKey,data,config,schedule)
intervals = data.targetIntervalsSec;
selected = false(schedule.frameCount,1);
for index = 1:size(intervals,1)
    selected = selected | (schedule.frameCenterTimeSec >= intervals(index,1) & ...
        schedule.frameCenterTimeSec <= intervals(index,2));
end
trajectory = satelliteFig3Trajectory(schedule.frameCenterTimeSec(selected),config);
if strcmp(regionKey,'high_doppler_rate')
    minimum = min(abs(trajectory.dopplerRateHzPerSec));
    maximum = max(abs(trajectory.dopplerRateHzPerSec));
    titleText = sprintf([ ...
        'High Doppler-rate region: |rate| %.1f--%.1f Hz/s, ' ...
        'payload drift >= 0.5 bin/frame'],minimum,maximum);
else
    minimum = min(abs(trajectory.dopplerShiftHz))/1e3;
    maximum = max(abs(trajectory.dopplerShiftHz))/1e3;
    titleText = sprintf([ ...
        'High Doppler-shift region: |shift| %.1f--%.1f kHz, ' ...
        'payload drift < 0.5 bin/frame'],minimum,maximum);
end
end

function label = localRecordRegion(regionKey)
if strcmp(regionKey,'high_doppler_rate')
    label = 'high_dynamic';
elseif strcmp(regionKey,'high_doppler_shift')
    label = 'low_dynamic';
else
    error('SatelliteFig3:Stage55RegionKey','Unknown region key.');
end
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
        'FaceAlpha',0.10,'EdgeColor','none','HandleVisibility','off');
end
end

function localShadeBlind(ax,window)
hold(ax,'on');
limits = ylim(ax);
blind = window.blindIntervalSec;
patch(ax,[blind(1) blind(2) blind(2) blind(1)], ...
    [limits(1) limits(1) limits(2) limits(2)],[0.88 0.88 0.88], ...
    'FaceAlpha',0.30,'EdgeColor','none','HandleVisibility','off');
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

function token = localSnrToken(snrDb)
token = strrep(sprintf('%g',snrDb),'-','minus');
end

function bitCount = localPayloadBitCount(config)
blockLength = 4+config.cr;
blockCount = config.payloadSymbolCount/blockLength;
bitCount = blockCount*4*config.sf;
end

function phaseRad = localWrapToPi(phaseRad)
phaseRad = mod(phaseRad+pi,2*pi)-pi;
end
