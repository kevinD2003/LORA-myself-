function report = run_stage50_continuous_pass_smoke(options)
%RUN_STAGE50_CONTINUOUS_PASS_SMOKE Paired time-axis full-pass smoke check.
%   Every frame slot is generated and advances the absolute Doppler phase.
%   To keep this inspection bounded, only a deterministic subset of fully
%   visible frames is decoded.  Formal statistics must use DecodeStride=1
%   and repeated passes in a new result directory.

arguments
    options.SampleSnrDb (1,1) double = -21
    options.DecodeStride (1,1) double {mustBeInteger,mustBePositive} = 4
    options.WindowDurationSec (1,1) double {mustBePositive} = 10
    options.PayloadSeedBase (1,1) double = 2026120300
    options.NoiseSeedBase (1,1) double = 2026120400
    options.MaxDecodedFrames (1,1) double = Inf
    options.ProgressEveryFrames (1,1) double = 50
    options.OutputFolderName (1,:) char = ...
        'stage50_continuous_pass_smoke'
end
if isfinite(options.MaxDecodedFrames) && ( ...
        options.MaxDecodedFrames < 1 || ...
        options.MaxDecodedFrames ~= round(options.MaxDecodedFrames))
    error('SatelliteFig3:SmokeMaxFrames', ...
        'MaxDecodedFrames must be Inf or a positive integer.');
end
if isfinite(options.ProgressEveryFrames) && ( ...
        options.ProgressEveryFrames < 1 || ...
        options.ProgressEveryFrames ~= round(options.ProgressEveryFrames))
    error('SatelliteFig3:SmokeProgress', ...
        'ProgressEveryFrames must be Inf or a positive integer.');
end

root = fileparts(mfilename('fullpath'));
resultDir = fullfile(root,'results',options.OutputFolderName);
if ~isfolder(resultDir), mkdir(resultDir); end
config = satelliteFig3Config();
schedule = satelliteFig3ContinuousPassSchedule(config);
window = schedule.window;
frameCount = schedule.frameCount;
methodNames = {'Huang-PREC-static-CP','SenLoRa-VP'};
methodCount = numel(methodNames);
known = zeros(config.bootstrapPilotCount,1);
payloadRows = (config.bootstrapPilotCount+1:config.frameSymbolCount).';

visibleIndex = find(schedule.fullyVisible);
selectedIndex = visibleIndex(1:options.DecodeStride:end);
% Deterministically include both lobe ends and both maximum-visible-rate
% neighborhoods.  This rule uses only geometry, never receiver results.
forced = [visibleIndex(1);visibleIndex(end)];
rateBoundary = config.centralVisibilityTimeSec+ ...
    [-window.deltaTimeInSec;window.deltaTimeInSec];
for boundary = 1:numel(rateBoundary)
    [~,nearest] = min(abs( ...
        schedule.frameCenterTimeSec(visibleIndex)-rateBoundary(boundary)));
    forced(end+1,1) = visibleIndex(nearest); %#ok<AGROW>
end
selectedIndex = unique([selectedIndex;forced]);
if isfinite(options.MaxDecodedFrames) && ...
        numel(selectedIndex) > options.MaxDecodedFrames
    positions = unique(round(linspace(1,numel(selectedIndex), ...
        options.MaxDecodedFrames))).';
    selectedIndex = selectedIndex(positions);
end
decodedFrameMask = false(frameCount,1);
decodedFrameMask(selectedIndex) = true;

payloadSeed = options.PayloadSeedBase+(1:frameCount).';
noiseSeed = options.NoiseSeedBase+(1:frameCount).';
bitCount = zeros(frameCount,1);
staticBitErrors = nan(frameCount,1);
senBitErrors = nan(frameCount,1);
staticFrameError = nan(frameCount,1);
senFrameError = nan(frameCount,1);
staticCfoSseBins = nan(frameCount,1);
senCfoSseBins = nan(frameCount,1);
cfoSampleCount = zeros(frameCount,1);
staticCfoRmseBins = nan(frameCount,1);
senCfoRmseBins = nan(frameCount,1);
staticEndResidualBins = nan(frameCount,1);
senEndResidualBins = nan(frameCount,1);
senAcceptedPilots = nan(frameCount,1);
senFalseAcceptedPilots = nan(frameCount,1);
senInitialRateBinsPerSec = nan(frameCount,1);
trueFrameCfoBins = nan(frameCount,1);
trueFrameRateBinsPerSec = nan(frameCount,1);
staticRuntimeSec = nan(frameCount,1);
senRuntimeSec = nan(frameCount,1);
initialPhaseRad = nan(frameCount,1);
lastSamplePhaseRad = nan(frameCount,1);
nextFrameStartPhaseRad = nan(frameCount,1);
phaseBridgeErrorRad = nan(frameCount,1);
phasePropagationErrorRad = nan(frameCount,1);
timeGapErrorSec = nan(frameCount,1);

phaseStateRad = 0;
previousLastPhaseRad = NaN;
previousLastDopplerHz = NaN;
previousLastTimeSec = NaN;
previousNextFrameStartPhaseRad = NaN;
for frame = 1:frameCount
    payload = satelliteFig3GeneratePayload(config,payloadSeed(frame));
    labels = [known;payload.symbolBins];
    [rx,~,truth] = generateContinuousSatelliteFrame(labels,config, ...
        StartTimeSec=schedule.frameStartTimeSec(frame), ...
        SampleSnrDb=options.SampleSnrDb,NoiseSeed=noiseSeed(frame), ...
        InitialPhaseRad=phaseStateRad,NextSymbolBin=0);
    initialPhaseRad(frame) = truth.initialPhaseRad;
    lastSamplePhaseRad(frame) = truth.lastSamplePhaseRad;
    nextFrameStartPhaseRad(frame) = truth.nextFrameStartPhaseRad;
    if frame > 1
        timeGapErrorSec(frame) = truth.sampleTimeSec(1,1)- ...
            previousLastTimeSec-1/config.sampleRateHz;
        expectedBridge = pi/config.sampleRateHz*( ...
            previousLastDopplerHz+truth.dopplerHz(1,1));
        phaseBridgeErrorRad(frame) = localWrapToPi( ...
            truth.phaseRad(1,1)-previousLastPhaseRad-expectedBridge);
        phasePropagationErrorRad(frame) = localWrapToPi( ...
            truth.initialPhaseRad-previousNextFrameStartPhaseRad);
    end
    % Absolute phase is periodic.  Carry the equivalent principal phase so
    % the 508-frame pass does not lose precision through subtraction of an
    % unnecessarily large unwrapped state (about 2e7 rad near mid-pass).
    phaseStateRad = localWrapToPi(truth.nextFrameStartPhaseRad);
    previousLastPhaseRad = truth.phaseRad(end,end);
    previousLastDopplerHz = truth.dopplerHz(end,end);
    previousLastTimeSec = truth.sampleTimeSec(end,end);
    previousNextFrameStartPhaseRad = truth.nextFrameStartPhaseRad;

    if decodedFrameMask(frame)
        timer = tic;
        staticPrec = satelliteFig3HuangPrecStaticCpDecode(rx,config,known);
        staticRuntimeSec(frame) = toc(timer);
        timer = tic;
        senlora = satelliteFig3SenLoRaVirtualPilotDecode(rx,config,known);
        senRuntimeSec(frame) = toc(timer);

        referenceBits = payload.dataBits(:);
        staticBits = staticPrec.decodedDataBits(:);
        senBits = senlora.hardDecodedDataBits(:);
        bitCount(frame) = numel(referenceBits);
        staticBitErrors(frame) = sum(staticBits ~= referenceBits);
        senBitErrors(frame) = sum(senBits ~= referenceBits);
        staticFrameError(frame) = staticBitErrors(frame) > 0;
        senFrameError(frame) = senBitErrors(frame) > 0;

        truePayloadCfoBins = truth.trueDopplerHz(payloadRows)/ ...
            config.fftBinSpacingHz;
        staticResidual = staticPrec.tracker.predictedCfoBins(payloadRows)- ...
            truePayloadCfoBins;
        senResidual = senlora.tracker.predictedCfoBins(payloadRows)- ...
            truePayloadCfoBins;
        staticCfoSseBins(frame) = sum(staticResidual.^2);
        senCfoSseBins(frame) = sum(senResidual.^2);
        cfoSampleCount(frame) = numel(payloadRows);
        staticCfoRmseBins(frame) = sqrt(mean(staticResidual.^2));
        senCfoRmseBins(frame) = sqrt(mean(senResidual.^2));
        staticEndResidualBins(frame) = staticResidual(end);
        senEndResidualBins(frame) = senResidual(end);
        accepted = senlora.pilotAccepted(payloadRows);
        senAcceptedPilots(frame) = sum(accepted);
        senFalseAcceptedPilots(frame) = sum(accepted & ...
            senlora.detectedWaveformBins(payloadRows) ~= labels(payloadRows));
        senInitialRateBinsPerSec(frame) = senlora.initialRateBinsPerSec;
        centerRow = round(mean(payloadRows));
        trueFrameCfoBins(frame) = truth.trueDopplerHz(centerRow)/ ...
            config.fftBinSpacingHz;
        trueFrameRateBinsPerSec(frame) = ...
            truth.trueDopplerRateHzPerSec(centerRow)/ ...
            config.fftBinSpacingHz;
    end

    if isfinite(options.ProgressEveryFrames) && ( ...
            mod(frame,options.ProgressEveryFrames) == 0 || ...
            frame == frameCount)
        fprintf('Stage 50 generated %d/%d frames; decoded %d/%d.\n', ...
            frame,frameCount,sum(decodedFrameMask(1:frame)), ...
            sum(decodedFrameMask));
    end
end

maxPhaseBridgeErrorRad = max(abs(phaseBridgeErrorRad(2:end)));
maxPhasePropagationErrorRad = max(abs(phasePropagationErrorRad(2:end)));
maxTimeGapErrorSec = max(abs(timeGapErrorSec(2:end)));
if maxPhaseBridgeErrorRad >= 1e-10 || ...
        maxPhasePropagationErrorRad >= 1e-10 || ...
        maxTimeGapErrorSec >= 1e-12
    error('SatelliteFig3:SmokeContinuity', ...
        ['The full-pass smoke stream is not time/phase continuous: ' ...
        'bridge %.3g rad, propagation %.3g rad, time %.3g s.'], ...
        maxPhaseBridgeErrorRad,maxPhasePropagationErrorRad, ...
        maxTimeGapErrorSec);
end

frameTable = schedule.frameTable;
frameTable.decoded = decodedFrameMask;
frameTable.payloadSeed = payloadSeed;
frameTable.noiseSeed = noiseSeed;
frameTable.bitCount = bitCount;
frameTable.staticBitErrors = staticBitErrors;
frameTable.senBitErrors = senBitErrors;
frameTable.staticFrameError = staticFrameError;
frameTable.senFrameError = senFrameError;
frameTable.staticCfoRmseBins = staticCfoRmseBins;
frameTable.senCfoRmseBins = senCfoRmseBins;
frameTable.staticEndResidualBins = staticEndResidualBins;
frameTable.senEndResidualBins = senEndResidualBins;
frameTable.senAcceptedPilots = senAcceptedPilots;
frameTable.senFalseAcceptedPilots = senFalseAcceptedPilots;
frameTable.senInitialRateBinsPerSec = senInitialRateBinsPerSec;
frameTable.trueFrameCfoBins = trueFrameCfoBins;
frameTable.trueFrameRateBinsPerSec = trueFrameRateBinsPerSec;
frameTable.staticRuntimeSec = staticRuntimeSec;
frameTable.senRuntimeSec = senRuntimeSec;
frameTable.initialPhaseRad = initialPhaseRad;
frameTable.lastSamplePhaseRad = lastSamplePhaseRad;
frameTable.nextFrameStartPhaseRad = nextFrameStartPhaseRad;
frameTable.phaseBridgeErrorRad = phaseBridgeErrorRad;
frameTable.phasePropagationErrorRad = phasePropagationErrorRad;
frameTable.timeGapErrorSec = timeGapErrorSec;
frameCsvPath = fullfile(resultDir,'stage50_frame_records.csv');
writetable(frameTable,frameCsvPath);

[windowTable,windowData] = localAggregateWindows(schedule,config,options, ...
    decodedFrameMask,bitCount,staticBitErrors,senBitErrors, ...
    staticFrameError,senFrameError,staticCfoSseBins,senCfoSseBins, ...
    cfoSampleCount,senAcceptedPilots);
windowCsvPath = fullfile(resultDir,'stage50_time_windows.csv');
writetable(windowTable,windowCsvPath);

methodSummary = localMethodSummary(schedule,config,methodNames, ...
    decodedFrameMask,bitCount,staticBitErrors,senBitErrors, ...
    staticFrameError,senFrameError,staticCfoSseBins,senCfoSseBins, ...
    cfoSampleCount,staticRuntimeSec,senRuntimeSec);
writetable(methodSummary,fullfile(resultDir,'stage50_method_summary.csv'));

imagePath = fullfile(resultDir,'stage50_continuous_pass_smoke.png');
localPlot(imagePath,resultDir,schedule,config,options,windowData, ...
    methodNames);
save(fullfile(resultDir,'stage50_continuous_pass_smoke.mat'), ...
    'config','options','schedule','frameTable','windowTable', ...
    'windowData','methodSummary','methodNames', ...
    'maxPhaseBridgeErrorRad','maxPhasePropagationErrorRad', ...
    'maxTimeGapErrorSec');

report = struct('resultDir',resultDir,'imagePath',imagePath, ...
    'frameCsvPath',frameCsvPath,'windowCsvPath',windowCsvPath, ...
    'schedule',schedule,'frameTable',frameTable, ...
    'windowTable',windowTable,'windowData',windowData, ...
    'methodSummary',methodSummary,'decodedFrameMask',decodedFrameMask, ...
    'decodedFrameCount',sum(decodedFrameMask), ...
    'generatedFrameCount',frameCount, ...
    'maxPhaseBridgeErrorRad',maxPhaseBridgeErrorRad, ...
    'maxPhasePropagationErrorRad',maxPhasePropagationErrorRad, ...
    'maxTimeGapErrorSec',maxTimeGapErrorSec);
fprintf('Stage 50 continuous-pass smoke: %s\n',resultDir);
disp(methodSummary);
end

function phaseRad = localWrapToPi(phaseRad)
phaseRad = mod(phaseRad+pi,2*pi)-pi;
end

function [windowTable,data] = localAggregateWindows(schedule,config,options, ...
        decodedMask,bitCount,staticErrors,senErrors,staticFrameError, ...
        senFrameError,staticCfoSse,senCfoSse,cfoCount,acceptedPilots)
edges = (schedule.passStartTimeSec:options.WindowDurationSec: ...
    schedule.passEndTimeSec).';
if edges(end) < schedule.passEndTimeSec
    edges(end+1,1) = schedule.passEndTimeSec;
else
    edges(end) = schedule.passEndTimeSec;
end
windowCount = numel(edges)-1;
windowIndex = (1:windowCount).';
windowStartTimeSec = edges(1:end-1);
windowEndTimeSec = edges(2:end);
windowCenterTimeSec = (windowStartTimeSec+windowEndTimeSec)/2;
visibleSlotCount = zeros(windowCount,1);
decodedFrameCount = zeros(windowCount,1);
bits = zeros(windowCount,1);
errors = nan(windowCount,2);
berRaw = nan(windowCount,2); berShown = berRaw;
berLower95 = berRaw; berUpper95 = berRaw;
frameErrors = nan(windowCount,2);
perRaw = nan(windowCount,2); perShown = perRaw;
perLower95 = perRaw; perUpper95 = perRaw;
cfoRmseBins = nan(windowCount,2);
goodputBps = nan(windowCount,2);
bitGoodRateBps = nan(windowCount,2);
meanAcceptedPilots = nan(windowCount,1);
nominalRateBps = 704/schedule.frameDurationSec;
for windowIndexValue = 1:windowCount
    inWindow = schedule.frameCenterTimeSec >= ...
        windowStartTimeSec(windowIndexValue) & ...
        schedule.frameCenterTimeSec < windowEndTimeSec(windowIndexValue);
    visibleSlotCount(windowIndexValue) = sum( ...
        inWindow & schedule.fullyVisible);
    selected = inWindow & decodedMask;
    decodedFrameCount(windowIndexValue) = sum(selected);
    if ~any(selected), continue; end
    bits(windowIndexValue) = sum(bitCount(selected));
    methodError = [sum(staticErrors(selected)),sum(senErrors(selected))];
    methodFrameError = [sum(staticFrameError(selected)), ...
        sum(senFrameError(selected))];
    errors(windowIndexValue,:) = methodError;
    frameErrors(windowIndexValue,:) = methodFrameError;
    for method = 1:2
        [berShown(windowIndexValue,method), ...
            berLower95(windowIndexValue,method), ...
            berUpper95(windowIndexValue,method)] = ...
            satelliteFig3BerInterval95(methodError(method), ...
            bits(windowIndexValue));
        berRaw(windowIndexValue,method) = methodError(method)/ ...
            bits(windowIndexValue);
        [perShown(windowIndexValue,method), ...
            perLower95(windowIndexValue,method), ...
            perUpper95(windowIndexValue,method)] = ...
            satelliteFig3BerInterval95(methodFrameError(method), ...
            decodedFrameCount(windowIndexValue));
        perRaw(windowIndexValue,method) = methodFrameError(method)/ ...
            decodedFrameCount(windowIndexValue);
    end
    cfoTotal = sum(cfoCount(selected));
    cfoRmseBins(windowIndexValue,1) = sqrt( ...
        sum(staticCfoSse(selected))/cfoTotal);
    cfoRmseBins(windowIndexValue,2) = sqrt( ...
        sum(senCfoSse(selected))/cfoTotal);
    goodputBps(windowIndexValue,:) = nominalRateBps*(1- ...
        perRaw(windowIndexValue,:));
    bitGoodRateBps(windowIndexValue,:) = nominalRateBps*(1- ...
        berRaw(windowIndexValue,:));
    meanAcceptedPilots(windowIndexValue) = mean(acceptedPilots(selected));
end
trajectory = satelliteFig3Trajectory(windowCenterTimeSec,config);
trueDopplerHz = trajectory.dopplerShiftHz;
trueDopplerRateHzPerSec = trajectory.dopplerRateHzPerSec;
windowTable = table(windowIndex,windowStartTimeSec,windowCenterTimeSec, ...
    windowEndTimeSec,visibleSlotCount,decodedFrameCount,bits, ...
    trueDopplerHz,trueDopplerRateHzPerSec, ...
    errors(:,1),errors(:,2),berRaw(:,1),berRaw(:,2), ...
    berShown(:,1),berShown(:,2),berLower95(:,1),berLower95(:,2), ...
    berUpper95(:,1),berUpper95(:,2),frameErrors(:,1),frameErrors(:,2), ...
    perRaw(:,1),perRaw(:,2),perShown(:,1),perShown(:,2), ...
    perLower95(:,1),perLower95(:,2),perUpper95(:,1),perUpper95(:,2), ...
    cfoRmseBins(:,1),cfoRmseBins(:,2),goodputBps(:,1),goodputBps(:,2), ...
    bitGoodRateBps(:,1),bitGoodRateBps(:,2),meanAcceptedPilots, ...
    'VariableNames',{'windowIndex','windowStartTimeSec', ...
    'windowCenterTimeSec','windowEndTimeSec','visibleSlotCount', ...
    'decodedFrameCount','bitCount','trueDopplerHz', ...
    'trueDopplerRateHzPerSec','staticBitErrors','senBitErrors', ...
    'staticBerRaw','senBerRaw','staticBerShown','senBerShown', ...
    'staticBerLower95','senBerLower95','staticBerUpper95','senBerUpper95', ...
    'staticFrameErrors','senFrameErrors','staticPerRaw','senPerRaw', ...
    'staticPerShown','senPerShown','staticPerLower95','senPerLower95', ...
    'staticPerUpper95','senPerUpper95','staticCfoRmseBins', ...
    'senCfoRmseBins','staticGoodputBps','senGoodputBps', ...
    'staticBitGoodRateBps','senBitGoodRateBps','meanSenAcceptedPilots'});
data = struct('centerTimeSec',windowCenterTimeSec, ...
    'trueDopplerHz',trueDopplerHz, ...
    'trueDopplerRateHzPerSec',trueDopplerRateHzPerSec, ...
    'decodedFrameCount',decodedFrameCount,'berRaw',berRaw, ...
    'berShown',berShown,'berLower95',berLower95, ...
    'berUpper95',berUpper95,'perRaw',perRaw,'perShown',perShown, ...
    'perLower95',perLower95,'perUpper95',perUpper95, ...
    'cfoRmseBins',cfoRmseBins,'goodputBps',goodputBps, ...
    'bitGoodRateBps',bitGoodRateBps, ...
    'meanAcceptedPilots',meanAcceptedPilots, ...
    'nominalRateBps',nominalRateBps);
end

function summary = localMethodSummary(schedule,config,methodNames, ...
        decodedMask,bitCount,staticErrors,senErrors,staticFrameError, ...
        senFrameError,staticCfoSse,senCfoSse,cfoCount, ...
        staticRuntime,senRuntime)
totalBits = sum(bitCount(decodedMask));
decodedFrames = sum(decodedMask);
errorMatrix = [sum(staticErrors(decodedMask)),sum(senErrors(decodedMask))];
frameErrorMatrix = [sum(staticFrameError(decodedMask)), ...
    sum(senFrameError(decodedMask))];
cfoSse = [sum(staticCfoSse(decodedMask)),sum(senCfoSse(decodedMask))];
cfoSamples = sum(cfoCount(decodedMask));
runtime = [mean(staticRuntime(decodedMask)),mean(senRuntime(decodedMask))];
ber = errorMatrix/totalBits;
per = frameErrorMatrix/decodedFrames;
nominalRateBps = 704/schedule.frameDurationSec;
activeLinkGoodputBps = nominalRateBps*(1-per);
passAverageDeliveryBps = 704*sum(schedule.fullyVisible)*(1-per)/ ...
    schedule.passSpanSec;
method = methodNames(:);
summary = table(method,repmat(decodedFrames,2,1), ...
    repmat(totalBits,2,1),errorMatrix(:),ber(:), ...
    frameErrorMatrix(:),per(:),sqrt(cfoSse(:)/cfoSamples), ...
    activeLinkGoodputBps(:),passAverageDeliveryBps(:),runtime(:), ...
    'VariableNames',{'method','decodedFrames','bitCount','bitErrors', ...
    'ber','frameErrors','per','cfoRmseBins','activeLinkGoodputBps', ...
    'passAverageDeliveryBps','meanRuntimeSecPerFrame'});
end

function localPlot(imagePath,resultDir,schedule,config,options,data,methodNames)
time = data.centerTimeSec;
colors = [0.85 0.15 0.10;0.00 0.35 0.85];
styles = {'s--','o-'};
fig = figure('Visible','off','Color','w','Position',[55 25 1420 1120]);
tiledlayout(5,1,'TileSpacing','compact','Padding','compact');

ax1 = nexttile;
yyaxis left;
plot(time,data.trueDopplerHz/1e3,'Color',[0 0.45 0.74], ...
    'LineWidth',1.5,'DisplayName','Doppler shift');
ylabel('Shift (kHz)');
yyaxis right;
plot(time,data.trueDopplerRateHzPerSec,'Color',[0.85 0.33 0.10], ...
    'LineWidth',1.5,'DisplayName','Doppler rate');
ylabel('Rate (Hz/s)');
grid on; grid minor;
title('Fixed-SNR continuous pass trajectory','FontWeight','normal');
localBlindLines(ax1,schedule.window);

ax2 = nexttile;
for method = 1:2
    valid = data.decodedFrameCount > 0 & isfinite(data.berShown(:,method));
    plotted = data.berShown(:,method);
    plotted(~valid) = NaN;
    semilogy(time,plotted,styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.25,'MarkerSize',4, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
    hold on;
end
grid on; grid minor; ylim([1e-4 1]);
ylabel('Window BER');
legend('Location','best','FontSize',8,'Box','on');
localShadeBlind(ax2,schedule.window);

ax3 = nexttile;
for method = 1:2
    valid = data.decodedFrameCount > 0 & isfinite(data.perRaw(:,method));
    plotted = data.perRaw(:,method);
    plotted(~valid) = NaN;
    plot(time,plotted,styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.25,'MarkerSize',4, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
    hold on;
end
grid on; grid minor; ylim([-0.03 1.03]);
ylabel('Window PER');
legend('Location','best','FontSize',8,'Box','on');
localShadeBlind(ax3,schedule.window);

ax4 = nexttile;
yyaxis left;
for method = 1:2
    valid = data.decodedFrameCount > 0 & ...
        isfinite(data.cfoRmseBins(:,method));
    plotted = max(data.cfoRmseBins(:,method),1e-5);
    plotted(~valid) = NaN;
    semilogy(time,plotted, ...
        styles{method},'Color',colors(method,:),'LineWidth',1.25, ...
        'MarkerSize',4,'MarkerFaceColor','none', ...
        'DisplayName',methodNames{method});
    hold on;
end
ylabel('CFO RMSE (bin)');
yyaxis right;
valid = data.decodedFrameCount > 0 & isfinite(data.meanAcceptedPilots);
plotted = data.meanAcceptedPilots;
plotted(~valid) = NaN;
plot(time,plotted,'b:', ...
    'LineWidth',1.2,'DisplayName','SenLoRa accepted pilots');
ylabel('Accepted pilots/frame');
grid on; grid minor;
localBlindLines(ax4,schedule.window);

ax5 = nexttile;
for method = 1:2
    valid = data.decodedFrameCount > 0 & ...
        isfinite(data.goodputBps(:,method));
    plotted = data.goodputBps(:,method);
    plotted(~valid) = NaN;
    plot(time,plotted,styles{method}, ...
        'Color',colors(method,:),'LineWidth',1.25,'MarkerSize',4, ...
        'MarkerFaceColor','none','DisplayName',methodNames{method});
    hold on;
end
yline(data.nominalRateBps,'k:','Nominal 716.1 bit/s', ...
    'HandleVisibility','off');
grid on; grid minor; ylim([0 1.08*data.nominalRateBps]);
ylabel('Goodput (bit/s)');
xlabel('Time relative to closest pass point (s)');
legend('Location','best','FontSize',8,'Box','on');
localShadeBlind(ax5,schedule.window);

axesList = [ax1 ax2 ax3 ax4 ax5];
for ax = axesList
    xlim(ax,[schedule.passStartTimeSec schedule.passEndTimeSec]);
    set(ax,'FontName','Times New Roman','FontSize',9.5,'Box','on', ...
        'GridLineStyle',':','MinorGridLineStyle',':');
end
sgtitle(sprintf(['Stage 50 one-pass smoke: Sample SNR %s dB, ' ...
    'decode every %d visible frames'],localSnrText(options.SampleSnrDb), ...
    options.DecodeStride),'FontName','Times New Roman', ...
    'FontWeight','normal');
exportgraphics(fig,imagePath,'Resolution',180);
savefig(fig,fullfile(resultDir,'stage50_continuous_pass_smoke.fig'));
close(fig);
end

function localShadeBlind(ax,window)
hold(ax,'on');
limits = ylim(ax);
blind = window.blindIntervalSec;
patch(ax,[blind(1) blind(2) blind(2) blind(1)], ...
    [limits(1) limits(1) limits(2) limits(2)], ...
    [0.88 0.88 0.88],'FaceAlpha',0.30,'EdgeColor','none', ...
    'HandleVisibility','off');
localBlindLines(ax,window);
ylim(ax,limits);
end

function localBlindLines(ax,window)
xline(ax,window.blindIntervalSec(1),'Color',[0.45 0.45 0.45], ...
    'LineStyle',':','HandleVisibility','off');
xline(ax,window.blindIntervalSec(2),'Color',[0.45 0.45 0.45], ...
    'LineStyle',':','HandleVisibility','off');
end

function text = localSnrText(snrDb)
if isinf(snrDb), text = 'Inf'; else, text = sprintf('%.1f',snrDb); end
end
