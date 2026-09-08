function result = sf12Stage55VpSerDecode(observation,bootstrap,cfg)
%SF12STAGE55VPSERDECODE Causal, no-FEC Stage55 VP-quality SF12 adapter.

layout = observation.layout;
nData = cfg.frame.payloadSymbolCount;
detected = nan(nData,1);
estimateAtData = nan(nData,1);
accepted = false(nData,1);
firstEffective = nan(nData,1);
innovationHz = nan(nData,1);
residualBoundary = false(nData,1);
stableDecision = false(nData,1);
peakRatio = nan(nData,1);
historyTime = nan(cfg.receiver.historyLength,1);
historyCfo = nan(cfg.receiver.historyLength,1);
historyCount = 0;
currentCfo = bootstrap.cfoHz;
currentRate = 0;
lastTime = layout.initialDownchirpStartTimeSec+ ...
    0.5*cfg.radio.symbolDurationSec;

for k = 1:nData
    row = layout.dataRows(k);
    time = layout.dataStartTimeSec(k);
    predicted = currentCfo+currentRate*(time-lastTime);
    estimateAtData(k) = predicted;
    hard1 = sf12HardDetect(observation.rxPhysical(row,:),predicted,cfg);
    detected(k) = hard1.symbol;
    residual = sf12EstimateResidualCfo( ...
        hard1.compensated,hard1.waveformBin,cfg);
    measurement = predicted+cfg.receiver.innovationGain*residual.offsetHz;
    hard2 = sf12HardDetect(observation.rxPhysical(row,:),measurement,cfg);
    stableDecision(k) = hard2.symbol == hard1.symbol;
    innovationHz(k) = residual.offsetHz;
    residualBoundary(k) = residual.atBoundary;
    peakRatio(k) = hard1.peakRatio;
    gate = hard1.peakRatio >= cfg.receiver.peakRatioThreshold && ...
        (~cfg.receiver.requireStableDecision || stableDecision(k)) && ...
        ~residual.atBoundary && ...
        abs(residual.offsetHz) <= cfg.receiver.innovationLimitHz;
    if gate
        accepted(k) = true;
        firstEffective(k) = k+1;
        if k == nData
            firstEffective(k) = NaN;
        end
        if historyCount < cfg.receiver.historyLength
            historyCount = historyCount+1;
            insert = historyCount;
        else
            historyTime(1:end-1) = historyTime(2:end);
            historyCfo(1:end-1) = historyCfo(2:end);
            insert = historyCount;
        end
        historyTime(insert) = time;
        historyCfo(insert) = measurement;
        currentCfo = measurement;
        lastTime = time;
        if historyCount >= 2
            t = historyTime(1:historyCount);
            y = historyCfo(1:historyCount);
            center = mean(t);
            beta = [ones(historyCount,1),t-center]\y;
            currentRate = max(-cfg.receiver.maximumRateHzPerSec,min( ...
                cfg.receiver.maximumRateHzPerSec,beta(2)));
            currentCfo = beta(1)+currentRate*(time-center);
        end
    end
end
result.method = "Stage55-VP-quality-SER";
result.detectedSymbols = detected;
result.estimatedCfoHz = estimateAtData;
result.initialCfoHz = bootstrap.cfoHz;
result.initialPhaseRad = bootstrap.phaseRad;
result.virtualPilotAccepted = accepted;
result.explicitMidambleAccepted = false(cfg.frame.toaMidambleCount,1);
result.pilotFirstEffectiveDataIndex = firstEffective;
result.innovationHz = innovationHz;
result.residualAtBoundary = residualBoundary;
result.stableDecision = stableDecision;
result.peakRatio = peakRatio;
result.usesPayloadTruth = false;
result.usesOrbitTruth = false;
result.usesCrossFrameState = false;
result.fftCount = 2*nData;
end
