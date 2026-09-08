function test_stage2_rolling8_receiver()
%TEST_STAGE2_ROLLING8_RECEIVER Test labels, soft blocks, and bootstrap sign.

config = satelliteFig3Config();
m = config.samplesPerSymbol;
for waveformBin = [0,1,7,73,m-1]
    waveform = satelliteFig3ModulateSymbol(waveformBin,config.sf);
    hard = satelliteFig3HardDecision(waveform,config);
    assert(hard.waveformBin == waveformBin, ...
        'Waveform-bin to MATLAB FFT-bin mapping is inconsistent.');
end

payload = satelliteFig3GeneratePayload(config,21);
bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
tx = complex(zeros(numel(bins),m));
for row = 1:numel(bins)
    tx(row,:) = satelliteFig3ModulateSymbol(bins(row),config.sf);
end
soft = satelliteFig3SenLoRaConfidence(tx,config);
payloadRows = config.bootstrapPilotCount+1:numel(bins);
assert(isequal(soft.decodedWaveformBins(payloadRows),bins(payloadRows)), ...
    'Soft Gray/diagonal/Hamming path does not round-trip the transmitter.');

[window,~] = satelliteFig3VisibilityWindow(config);
[rx,~,truth] = generateContinuousSatelliteFrame(bins,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf);
tracker = satelliteFig3RollingPilotTracker(rx,config, ...
    zeros(config.bootstrapPilotCount,1));
truthCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
bootstrapError = max(abs(tracker.measuredCfoBins(1:config.bootstrapPilotCount)- ...
    truthCfoBins(1:config.bootstrapPilotCount)));
assert(bootstrapError < 0.05, ...
    'Bootstrap CFO sign or scale disagrees with the exact channel.');
assert(all(tracker.activeHistoryCount(config.bootstrapPilotCount:end) == ...
    config.virtualPilotHistoryLength), ...
    'Active pilot history must remain exactly eight slots after bootstrap.');
fprintf('Stage 2 receiver tests passed.\\n');
end
