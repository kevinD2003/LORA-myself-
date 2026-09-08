classdef test_stage3_physics_layers < SenLoRaStageTestCase
    %TEST_STAGE3_PHYSICS_LAYERS MATLAB unit-test wrapper for this stage regression.

    methods (Test)
        function runRegression(~)
            check_test_stage3_physics_layers();
        end
    end
end

function check_test_stage3_physics_layers()
%TEST_STAGE3_PHYSICS_LAYERS Verify AWGN and ideal phase-compensation layers.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
payload = satelliteFig3GeneratePayload(config,31);
bins = [zeros(config.bootstrapPilotCount,1);payload.symbolBins];
[rx,tx,truth] = generateContinuousSatelliteFrame(bins,config, ...
    StartTimeSec=window.deltaTimeInSec,SampleSnrDb=Inf);
ideal = rx.*exp(-1i*truth.phaseRad);
decodedIdeal = localDecode(ideal,config);
decodedAwgn = localDecode(tx,config);
assert(isequal(decodedIdeal,bins), ...
    'Exact phase compensation must recover every noiseless symbol.');
assert(isequal(decodedAwgn,bins), ...
    'The pure AWGN reference mapping must recover every noiseless symbol.');
fprintf('Stage 3 physics-layer tests passed.\\n');
end

function bins = localDecode(symbols,config)
bins = zeros(size(symbols,1),1);
for row = 1:size(symbols,1)
    decision = satelliteFig3HardDecision(symbols(row,:),config);
    bins(row) = decision.waveformBin;
end
end
