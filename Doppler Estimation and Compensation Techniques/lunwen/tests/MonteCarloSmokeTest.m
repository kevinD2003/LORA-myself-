classdef MonteCarloSmokeTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testLdroAcceptsOneBinResidual(testCase)
            cfg = paperSf12Config();
            sampleTimeS = (0:cfg.radio.samplesPerSymbol-1).'/ ...
                cfg.radio.sampleRateHz;
            oneBinResidual = exp(1j*2*pi*cfg.radio.fftBinHz*sampleTimeS);
            errors = detectZeroSymbolBatch( ...
                oneBinResidual, 1, 0, 100, cfg);
            testCase.verifyEqual(errors, 0);
        end

        function testNoDopplerSinglePacket(testCase)
            cfg = paperSf12Config();
            limits = struct('batchPackets', 1, 'minimumPackets', 1, ...
                'maximumPackets', 1, 'minimumSymbolErrors', 0);
            result = simulateSerPoint( ...
                cfg, "case2", "no_doppler", -21, limits);
            testCase.verifyEqual(result.totalSymbols, 23);
            testCase.verifyFalse(result.fittedOrTuned);
        end

        function testPointSinglePacket(testCase)
            cfg = paperSf12Config();
            limits = struct('batchPackets', 1, 'minimumPackets', 1, ...
                'maximumPackets', 1, 'minimumSymbolErrors', 0);
            result = simulateSerPoint( ...
                cfg, "case2", "point", -21, limits);
            testCase.verifyEqual(result.totalSymbols, 23);
            testCase.verifyFalse(result.fittedOrTuned);
        end

        function testMidamblePointSinglePacket(testCase)
            cfg = paperSf12Config();
            limits = struct('batchPackets', 1, 'minimumPackets', 1, ...
                'maximumPackets', 1, 'minimumSymbolErrors', 0);
            result = simulateSerPoint( ...
                cfg, "case2", "midamble_point", -21, limits);
            testCase.verifyEqual(result.totalSymbols, 23);
            testCase.verifyFalse(result.fittedOrTuned);
        end
    end
end
