function result = sf12PaperMidambleDecode(observation,bootstrap,cfg)
%SF12PAPERMIDAMBLEDECODE Paper Midamble-Point, n_int=3, zero delay.

layout = observation.layout;
nData = cfg.frame.payloadSymbolCount;
detected = nan(nData,1);
estimateAtData = nan(nData,1);
currentCfo = bootstrap.cfoHz;
effectiveAt = nan(cfg.frame.toaMidambleCount,1);
accepted = false(cfg.frame.toaMidambleCount,1);
midambleIndex = 0;
for row = 1:layout.physicalSymbolCount
    if layout.kind(row) == "data"
        k = layout.dataIndex(row);
        estimateAtData(k) = currentCfo;
        hard = sf12HardDetect(observation.rxPhysical(row,:),currentCfo,cfg);
        detected(k) = hard.symbol;
    else
        midambleIndex = midambleIndex+1;
        if midambleIndex <= cfg.frame.trackingMidambleCount
            pilot = sf12HardDetect(observation.rxPhysical(row,:),currentCfo,cfg);
            residualHz = sf12EstimateSignedFftFrequency( ...
                pilot.compensated,cfg.radio.sampleRateHz, ...
                cfg.radio.samplesPerSymbol);
            currentCfo = currentCfo+residualHz;
            accepted(midambleIndex) = true;
            effectiveAt(midambleIndex) = ...
                layout.midambleAfterDataIndex(midambleIndex)+1;
        end
    end
end
result.method = "Paper-Midamble-Point";
result.detectedSymbols = detected;
result.estimatedCfoHz = estimateAtData;
result.initialCfoHz = bootstrap.cfoHz;
result.initialPhaseRad = bootstrap.phaseRad;
result.virtualPilotAccepted = false(nData,1);
result.explicitMidambleAccepted = accepted;
result.pilotFirstEffectiveDataIndex = effectiveAt;
result.usesPayloadTruth = false;
result.usesOrbitTruth = false;
result.usesCrossFrameState = false;
result.fftCount = nData+2*cfg.frame.trackingMidambleCount;
end
