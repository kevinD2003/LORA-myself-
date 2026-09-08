classdef test_stage47_paper_prec_continuous_phase < SenLoRaStageTestCase
    %TEST_STAGE47_PAPER_PREC_CONTINUOUS_PHASE MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage47_paper_prec_continuous_phase();
        end
    end
end

function check_test_stage47_paper_prec_continuous_phase()
%TEST_STAGE47_PAPER_PREC_CONTINUOUS_PHASE Document the model assumption.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
startTimes = [-window.deltaTimeOutSec,window.deltaTimeInSec];
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026111301);
labels = [known;payload.symbolBins];
expectedMaximumGain = 0.25;
for scene = 1:numel(startTimes)
    [~,tx,truth] = generateContinuousSatelliteFrame(labels,config, ...
        StartTimeSec=startTimes(scene),SampleSnrDb=Inf,NoiseSeed=1);
    clean = tx.*exp(1i*truth.phaseRad);
    paper = satelliteFig3PaperPrecDecode(clean,config,known);
    truePreambleCfoBins = mean(truth.trueDopplerHz( ...
        1:config.bootstrapPilotCount,:),'all')/config.fftBinSpacingHz;
    assert(abs(paper.epsilonHatBins-truePreambleCfoBins) < 0.051, ...
        'Noise-free continuous-phase Paper PREC has an indexing/sign error.');
    assert(paper.preambleCoherentGain < expectedMaximumGain, ...
        ['The Figure-3 phase convention no longer exposes the documented ', ...
        'cross-preamble cancellation; review this audit if the channel changes.']);
end
fprintf('Stage 47 continuous-phase Paper-PREC assumption test passed.\n');
end
