function test_stage48_huang_prec_cp_source()
%TEST_STAGE48_HUANG_PREC_CP_SOURCE Preserve Huang's eta/FFT/CFO logic.

config = satelliteFig3Config();
known = zeros(config.bootstrapPilotCount,1);
m = config.samplesPerSymbol;
n = 0:m-1;
epsilonCases = [149.2,-58.3,18.2,-7.3,0.5];
for epsilon = epsilonCases
    preambles = complex(zeros(config.bootstrapPilotCount,m));
    for pilot = 1:config.bootstrapPilotCount
        % Paper-compatible reference: every symbol uses Huang's local k.
        preambles(pilot,:) = satelliteFig3ModulateSymbol(0,config.sf).* ...
            exp(1i*2*pi*epsilon*n/m);
    end
    payload = complex(zeros(4+config.cr,m));
    for symbol = 1:size(payload,1)
        payload(symbol,:) = satelliteFig3ModulateSymbol(123,config.sf).* ...
            exp(1i*2*pi*epsilon*n/m);
    end
    exact = satelliteFig3PaperPrecDecode( ...
        [preambles;payload],config,known);
    adapted = satelliteFig3HuangPrecCpBootstrapEstimate( ...
        preambles,known,config);
    assert(adapted.epsilonHatBins == exact.epsilonHatBins, ...
        'The CP adaptation changed Huang''s noise-free eta/FFT estimate.');
    assert(abs(adapted.epsilonHatBins-epsilon) <= 0.0500001, ...
        'The CP estimate exceeded Huang''s 0.1-bin search resolution.');
end

seniorSource = ['D:\codex\师兄代码\matlab\CFO相关\频移算法\', ...
    '卫星信道\卫星信道\MonteCarlo_BER_RMSE_PRC_EC_TQ28.m'];
sourceText = fileread(seniorSource);
requiredTokens = {'r_pre_ave','eta_fraction=(0:0.1:1)', ...
    'epsilon_integer_estimation','-epsilon_integer_estimation+eta_fraction_estimation+1'};
for token = requiredTokens
    assert(contains(sourceText,token{1}), ...
        'The declared Huang/PRC source no longer matches the adapter.');
end

fprintf('Stage 48 Huang-PREC CP source-equivalence test passed.\n');
end
