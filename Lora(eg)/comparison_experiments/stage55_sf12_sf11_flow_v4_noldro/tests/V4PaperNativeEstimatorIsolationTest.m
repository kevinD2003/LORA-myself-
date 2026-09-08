classdef V4PaperNativeEstimatorIsolationTest < matlab.unittest.TestCase
    methods (Test)
        function signedIntegerBinsAreRecovered(testCase)
            c = sf12NoLdroSf11FlowConfig(); down = conj(v4ModulateSymbol(0,c));
            n = 0:c.samplesPerSymbol-1;
            for bin = [-100 0 17]
                rx = down.*exp(1i*2*pi*bin*n/c.samplesPerSymbol);
                estimate = v4PaperNativePointEstimate(rx,c);
                testCase.verifyEqual(estimate.offsetBins,bin);
                testCase.verifyEqual(estimate.resolution,'integer-fft-bin');
            end
        end
        function nativeCallGraphHasNoSubBinEstimator(testCase)
            root = v4SetupPaths();
            files = {'v4PaperNativePointEstimate.m','v4PaperNativeMidambleDecode.m'};
            for index = 1:numel(files)
                content = fileread(fullfile(root,'src','paper_anchor',files{index}));
                testCase.verifyFalse(contains(content,'v4PhaseRotationEstimate('));
                testCase.verifyFalse(contains(content,'truth.'));
            end
        end
    end
end
