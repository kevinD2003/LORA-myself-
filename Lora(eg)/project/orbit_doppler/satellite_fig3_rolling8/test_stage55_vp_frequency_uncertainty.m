classdef test_stage55_vp_frequency_uncertainty < SenLoRaStageTestCase
    %TEST_STAGE55_VP_FREQUENCY_UNCERTAINTY MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage55_vp_frequency_uncertainty();
        end
    end
end

function check_test_stage55_vp_frequency_uncertainty()
%TEST_STAGE55_VP_FREQUENCY_UNCERTAINTY Receiver-only CFO uncertainty output.

config = satelliteFig3Config();
symbol = satelliteFig3ModulateSymbol(317,config.sf);
n = 0:config.samplesPerSymbol-1;
offset = 0.08;
clean = symbol.*exp(1i*(0.3+2*pi*offset*n/config.samplesPerSymbol));
cleanEstimate = satelliteFig3PhaseRotationEstimate(clean,317,config, ...
    CandidateOffsets=config.residualSearchBins,LocalOnly=true);
stream = RandStream('mt19937ar','Seed',2026460901);
noise = sqrt(50)*(randn(stream,size(clean))+ ...
    1i*randn(stream,size(clean)));
noisyEstimate = satelliteFig3PhaseRotationEstimate(clean+noise,317,config, ...
    CandidateOffsets=config.residualSearchBins,LocalOnly=true);

% The production estimator uses a 0.1-bin search grid followed by local
% parabolic interpolation; require accuracy well below one percent of a
% grid step rather than an unattainable analytic-zero error.
assert(abs(cleanEstimate.offsetBins-offset) < 1e-3, ...
    'The clean CFO estimate is inaccurate.');
assert(isfinite(cleanEstimate.frequencyStdBins) && ...
    isfinite(noisyEstimate.frequencyStdBins) && ...
    cleanEstimate.frequencyStdBins < noisyEstimate.frequencyStdBins, ...
    'The receiver-only CFO uncertainty does not increase with noise.');
assert(noisyEstimate.frequencyStdBins > 0 && ...
    noisyEstimate.residualNoisePower > cleanEstimate.residualNoisePower, ...
    'The uncertainty diagnostic is outside its physical range.');
fprintf('Stage 55 VP frequency-uncertainty test passed.\n');
end
