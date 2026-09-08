function test_stage3_stable_admission()
%TEST_STAGE3_STABLE_ADMISSION Guard against oscillating low-SNR pilot masks.
%   These deterministic frames previously showed that the fifth iteration
%   could accept a payload symbol whose own final decoded label was wrong.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
for frame = 2:3
    payload = satelliteFig3GeneratePayload(config, ...
        config.randomSeedSymbols + 2000 + frame);
    bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
    rx = generateContinuousSatelliteFrame(bins,config, ...
        StartTimeSec=window.deltaTimeInSec,SampleSnrDb=-22, ...
        NoiseSeed=config.randomSeedNoise + 2000 + frame);
    result = satelliteFig3SenLoRaIterativeDecode(rx,config, ...
        zeros(config.bootstrapPilotCount,1));
    rows = config.bootstrapPilotCount+(1:config.payloadSymbolCount);
    falseAccepted = result.pilotAccepted(rows) & ...
        result.detectedWaveformBins(rows) ~= bins(rows);
    assert(~any(falseAccepted), ...
        'Oscillating confidence mask admitted a wrong virtual pilot.');
end
fprintf('Stable-admission regression test passed.\\n');
end
