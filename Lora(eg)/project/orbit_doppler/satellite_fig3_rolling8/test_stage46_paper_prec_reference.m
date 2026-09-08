classdef test_stage46_paper_prec_reference < SenLoRaStageTestCase
    %TEST_STAGE46_PAPER_PREC_REFERENCE MATLAB unit-test wrapper for this regression.

    methods (Test)
        function runRegression(~)
            check_test_stage46_paper_prec_reference();
        end
    end
end

function check_test_stage46_paper_prec_reference()
%TEST_STAGE46_PAPER_PREC_REFERENCE Check the callable thesis PREC baseline.

config = satelliteFig3Config();
known = zeros(config.bootstrapPilotCount,1);
payload = satelliteFig3GeneratePayload(config,2026111001);
labels = [known;payload.symbolBins];
m = config.samplesPerSymbol;
n = 0:m-1;
epsilonCases = [149.2,-58.3,18.2,-7.3,0.5];
for epsilon = epsilonCases
    tx = complex(zeros(numel(labels),m));
    for symbol = 1:numel(labels)
        tx(symbol,:) = satelliteFig3ModulateSymbol(labels(symbol),config.sf).* ...
            exp(1i*2*pi*epsilon*n/m);
    end
    result = satelliteFig3PaperPrecDecode(tx,config,known);
    assert(abs(result.epsilonHatBins-epsilon) <= 0.0500001, ...
        'Paper PREC exceeded the declared 0.1-bin eta quantisation error.');
    assert(isequal(result.decodedDataBits,payload.dataBits), ...
        'Paper PREC did not recover a noise-free constant-CFO payload.');
    assert(~result.usesPayloadFeedback && ~result.usesDopplerRate, ...
        'The paper baseline contains a non-paper tracking extension.');
end

seniorSource = ['D:\codex\师兄代码\matlab\CFO相关\频移算法\', ...
    '卫星信道\卫星信道\MonteCarlo_BER_RMSE_PRC_EC_TQ28.m'];
assert(isfile(seniorSource),'The declared senior-code PREC source is missing.');
sourceText = fileread(seniorSource);
requiredTokens = {'r_pre_ave','eta_fraction=(0:0.1:1)', ...
    'epsilon_integer_estimation','exp(1j*2*pi*k'};
for token = requiredTokens
    assert(contains(sourceText,token{1}), ...
        'The senior-code source no longer matches the documented PREC logic.');
end
fprintf('Stage 46 paper-PREC reference test passed.\n');
end
