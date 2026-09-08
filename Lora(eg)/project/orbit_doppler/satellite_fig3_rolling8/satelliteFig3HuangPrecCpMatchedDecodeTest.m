classdef satelliteFig3HuangPrecCpMatchedDecodeTest < matlab.unittest.TestCase
    %SATELLITEFIG3HUANGPRECCPMATCHEDDECODETEST Regression tests.

    properties (TestParameter)
        cfoBins = struct('largePositive',149.2,'largeNegative',-58.3)
    end

    methods (TestMethodSetup)
        function preserveRandomState(testCase)
            original = rng;
            testCase.addTeardown(@()rng(original));
            rng(20260812,'twister');
        end
    end

    methods (Test)
        function testNoiseFreeContinuousPhaseCfo(testCase,cfoBins)
            config = satelliteFig3Config();
            known = zeros(config.bootstrapPilotCount,1);
            payload = satelliteFig3GeneratePayload(config,2026552601);
            labels = [known;payload.symbolBins];
            rx = localConstantContinuousCfoFrame(labels,config,cfoBins);

            decoded = satelliteFig3HuangPrecCpMatchedDecode( ...
                rx,config,known);

            testCase.verifyLessThanOrEqual( ...
                abs(decoded.bootstrap.epsilonHatBins-cfoBins),0.0500001);
            testCase.verifyEqual(decoded.hardDecodedDataBits(:), ...
                payload.dataBits(:));
            testCase.verifyEqual(decoded.decodedDataBits(:), ...
                payload.dataBits(:));
        end

        function testComparisonMetadata(testCase)
            config = satelliteFig3Config();
            known = zeros(config.bootstrapPilotCount,1);
            payload = satelliteFig3GeneratePayload(config,2026552602);
            labels = [known;payload.symbolBins];
            rx = localConstantContinuousCfoFrame(labels,config,18.2);

            decoded = satelliteFig3HuangPrecCpMatchedDecode( ...
                rx,config,known);

            testCase.verifyTrue(decoded.continuousPhaseAdapted);
            testCase.verifyFalse(decoded.usesPayloadFeedback);
            testCase.verifyFalse(decoded.usesDopplerRate);
            testCase.verifyFalse(decoded.usesOrbitPrior);
            testCase.verifySubstring(decoded.algorithmProvenance, ...
                'Huang thesis (4-1)--(4-7)');
            testCase.verifySubstring(decoded.finalDecodeMetric, ...
                'same raw-bit LLR engine as Stage55');
        end
    end
end

function rx = localConstantContinuousCfoFrame(labels,config,cfoBins)
symbolCount = numel(labels);
m = config.samplesPerSymbol;
tx = complex(zeros(symbolCount,m));
for symbol = 1:symbolCount
    tx(symbol,:) = satelliteFig3ModulateSymbol(labels(symbol),config.sf);
end
sampleIndex = reshape(0:numel(tx)-1,m,symbolCount).';
rx = tx.*exp(1i*2*pi*cfoBins*sampleIndex/m);
end
