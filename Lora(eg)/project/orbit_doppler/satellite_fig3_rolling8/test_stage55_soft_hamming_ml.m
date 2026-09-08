classdef test_stage55_soft_hamming_ml < SenLoRaStageTestCase
    %TEST_STAGE55_SOFT_HAMMING_ML MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage55_soft_hamming_ml();
        end
    end
end

function check_test_stage55_soft_hamming_ml()
%TEST_STAGE55_SOFT_HAMMING_ML Validate receiver-visible ML soft decoding.

config = satelliteFig3Config();
[window,~] = satelliteFig3VisibilityWindow(config);
known = zeros(config.bootstrapPilotCount,1);
snrGrid = [-21;-20];
hardErrors = zeros(size(snrGrid));
softErrors = zeros(size(snrGrid));
frameCount = 16;
for snrIndex = 1:numel(snrGrid)
    for frame = 1:frameCount
        payload = satelliteFig3GeneratePayload( ...
            config,2026280800+1000*snrIndex+frame);
        labels = [known;payload.symbolBins];
        [rx,~,truth] = generateContinuousSatelliteFrame(labels,config, ...
            StartTimeSec=window.deltaTimeInSec, ...
            SampleSnrDb=snrGrid(snrIndex), ...
            NoiseSeed=2026280900+1000*snrIndex+frame);
        compensated = rx.*exp(-1i*truth.phaseRad);
        pass = satelliteFig3SenLoRaConfidence(compensated,config);
        assert(isfield(pass,'mlDecodedDataBits'), ...
            'The confidence decoder does not expose ML soft-Hamming bits.');
        payloadRows = config.bootstrapPilotCount+1:config.frameSymbolCount;
        hardBins = zeros(config.payloadSymbolCount,1);
        for row = 1:config.payloadSymbolCount
            hard = satelliteFig3HardDecision( ...
                compensated(payloadRows(row),:),config);
            hardBins(row) = hard.waveformBin;
        end
        hardBits = satelliteFig3HardPayloadBits(hardBins,config);
        hardErrors(snrIndex) = hardErrors(snrIndex)+sum( ...
            hardBits(:) ~= payload.dataBits(:));
        softErrors(snrIndex) = softErrors(snrIndex)+sum( ...
            pass.mlDecodedDataBits(:) ~= payload.dataBits(:));
    end
end
assert(all(softErrors <= hardErrors), ...
    'ML soft-Hamming decoding is worse than hard Hamming in the audit set.');
assert(any(softErrors < hardErrors), ...
    'The soft-Hamming audit does not demonstrate any coding gain.');
fprintf('Stage 55 ML soft-Hamming test passed: hard=%s, soft=%s.\n', ...
    mat2str(hardErrors.'),mat2str(softErrors.'));
end
