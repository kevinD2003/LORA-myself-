classdef Sf7ConfigurationTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testPaperParameters(testCase)
            cfg = paperSf7Config();
            testCase.verifyEqual(cfg.radio.spreadingFactor, 7);
            testCase.verifyFalse(cfg.radio.ldro);
            testCase.verifyEqual(cfg.radio.samplesPerSymbol, 128);
            testCase.verifyEqual(cfg.radio.fftBinHz, ...
                976.5625, 'AbsTol', 1e-12);
            testCase.verifyEqual( ...
                cfg.frame.midambleSpacingDataSymbols, 12);
        end

        function testPayloadAndMidambleLayout(testCase)
            cfg = paperSf7Config();
            layout = buildFrameLayout(cfg);
            testCase.verifyEqual(layout.payloadSymbols, 33);
            testCase.verifyEqual(layout.numberOfMidambles, 3);
            testCase.verifyEqual(find( ...
                layout.slotKind == "midamble"), [13 26 36]);
        end

        function testTableThreeToa(testCase)
            cfg = paperSf7Config();
            layout = buildFrameLayout(cfg);
            testCase.verifyEqual(layout.pointToaS, ...
                0.044288, 'AbsTol', 1e-12);
            testCase.verifyEqual(layout.midamblePointToaS, ...
                0.04736, 'AbsTol', 1e-12);
            testCase.verifyLessThan(abs(layout.pointToaS - ...
                cfg.paper.pointToaS), 1e-3);
            testCase.verifyLessThan(abs(layout.midamblePointToaS - ...
                cfg.paper.midamblePointToaS), 1e-3);
        end

        function testCase2TrackingRemainsPiecewiseConstant(testCase)
            cfg = paperSf7Config();
            trace = buildTrackingTrace(cfg, "case2");
            testCase.verifyEqual(numel(trace.updateTimeS)-1, 3);
            testCase.verifyEqual(numel(unique( ...
                trace.pointEstimateHz)), 1);
        end
    end
end
