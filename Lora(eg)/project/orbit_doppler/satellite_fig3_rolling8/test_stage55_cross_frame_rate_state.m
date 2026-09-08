classdef test_stage55_cross_frame_rate_state < SenLoRaStageTestCase
    %TEST_STAGE55_CROSS_FRAME_RATE_STATE MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage55_cross_frame_rate_state();
        end
    end
end

function check_test_stage55_cross_frame_rate_state()
%TEST_STAGE55_CROSS_FRAME_RATE_STATE Reject noisy 65-ms rate extrapolation.

config = satelliteFig3Config();
schedule = satelliteFig3ContinuousPassSchedule(config);
known = zeros(config.bootstrapPilotCount,1);
snrGrid = [-21;-20];
segmentStart = [1;247;493];
segmentLength = 16;
legacyError = zeros(0,1);
crossFrameError = zeros(0,1);
historyCount = zeros(0,1);
for snrIndex = 1:numel(snrGrid)
    for segmentIndex = 1:numel(segmentStart)
        state = struct();
        for offset = 0:segmentLength-1
            frameIndex = segmentStart(segmentIndex)+offset;
            [rx,~,truth] = generateContinuousSatelliteFrame(known,config, ...
                StartTimeSec=schedule.frameStartTimeSec(frameIndex), ...
                SampleSnrDb=snrGrid(snrIndex), ...
                NoiseSeed=2026310900+10000*snrIndex+frameIndex);
            bootstrap = satelliteFig3HuangPrecCpBootstrapEstimate( ...
                rx,known,config);
            measurementTime = schedule.frameStartTimeSec(frameIndex)+ ...
                0.5*config.bootstrapPilotCount*config.symbolDurationSec;
            [rate,state,diagnostic] = satelliteFig3CrossFrameRateUpdate( ...
                state,measurementTime,bootstrap.epsilonHatBins, ...
                bootstrap.jointRateBinsPerSec,config);
            trueRate = mean(truth.trueDopplerRateHzPerSec)/ ...
                config.fftBinSpacingHz;
            if offset >= config.virtualPilotHistoryLength-1
                legacyError(end+1,1) = ... %#ok<AGROW>
                    bootstrap.jointRateBinsPerSec-trueRate;
                crossFrameError(end+1,1) = rate-trueRate; %#ok<AGROW>
                historyCount(end+1,1) = diagnostic.historyCount; %#ok<AGROW>
            end
        end
    end
end
legacyRmse = sqrt(mean(legacyError.^2));
crossFrameRmse = sqrt(mean(crossFrameError.^2));
assert(all(historyCount == config.virtualPilotHistoryLength), ...
    'The cross-frame rate state is not a fixed rolling-8 history.');
assert(crossFrameRmse < 0.35*legacyRmse, ...
    'Cross-frame CFO inheritance does not sufficiently reduce rate RMSE.');
assert(crossFrameRmse < 0.12, ...
    'The inherited rate is not reliable enough for one-frame prediction.');
assert(max(abs(crossFrameError)) < 0.30, ...
    'The inherited rate still contains a payload-scale outlier.');
fprintf(['Stage 55 cross-frame rate test passed: legacy %.4f, ' ...
    'rolling-8 %.4f bin/s RMSE; worst %.4f bin/s.\n'], ...
    legacyRmse,crossFrameRmse,max(abs(crossFrameError)));
end
