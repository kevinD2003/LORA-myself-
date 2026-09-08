classdef test_stage14_hard_prec < SenLoRaStageTestCase
    %TEST_STAGE14_HARD_PREC MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage14_hard_prec();
        end
    end
end

function check_test_stage14_hard_prec()
%TEST_STAGE14_HARD_PREC Verify the receiver-only hard-PREC baseline.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
starts = [-window.deltaTimeOutSec,window.deltaTimeInSec];

for scenario = 1:numel(starts)
    payload = satelliteFig3GeneratePayload(config,2026081500+scenario);
    bins = [known;payload.symbolBins];
    [rx,~,truth] = generateContinuousSatelliteFrame(bins,config, ...
        StartTimeSec=starts(scenario),SampleSnrDb=Inf, ...
        NoiseSeed=2026081600+scenario);
    hardPrec = satelliteFig3HardPrecDecode(rx,config,known);
    payloadRows = config.bootstrapPilotCount+1:numel(bins);

    assert(isequal(hardPrec.detectedWaveformBins(payloadRows), ...
        bins(payloadRows)), ...
        'Noiseless hard PREC must recover every payload symbol.');
    assert(isequal(hardPrec.decodedDataBits,payload.dataBits), ...
        'Noiseless hard PREC must recover every payload data bit.');
    assert(all(hardPrec.requestedMask(payloadRows)), ...
        'Every payload hard decision must request admission.');
    assert(any(hardPrec.pilotAccepted(payloadRows)), ...
        'Noiseless hard PREC must accept dynamic virtual pilots.');
    acceptedPayloadRows = payloadRows(hardPrec.pilotAccepted(payloadRows));
    acceptedResidual = abs(hardPrec.tracker.measuredResidualBins( ...
        acceptedPayloadRows));
    assert(all(acceptedResidual <= ...
        config.confidenceInnovationLimitBins+10*eps), ...
        'An accepted hard pilot exceeded the innovation limit.');

    truthCfoBins = truth.trueDopplerHz/config.fftBinSpacingHz;
    predictionError = hardPrec.tracker.predictedCfoBins(payloadRows)- ...
        truthCfoBins(payloadRows);
    assert(sqrt(mean(predictionError.^2)) < 0.02, ...
        'Noiseless hard PREC CFO prediction RMSE exceeded 0.02 bin.');
end

fprintf('Stage 14 hard-PREC tests passed.\n');
end
