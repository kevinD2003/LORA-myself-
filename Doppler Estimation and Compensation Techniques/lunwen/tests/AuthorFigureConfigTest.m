classdef AuthorFigureConfigTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testSf12SourceProfile(testCase)
            cfg = authorFigureSf12Config();
            layout = buildFrameLayout(cfg);
            testCase.verifyEqual(cfg.channel.model, "awgn_only");
            testCase.verifyEqual( ...
                cfg.frame.midambleSpacingDataSymbols, 1);
            testCase.verifyEqual(layout.numberOfMidambles, 23);
            testCase.verifyEqual(layout.midamblePointToaS, ...
                1.8432, 'AbsTol', 1e-12);
            testCase.verifyFalse(cfg.provenance.fittedOrTuned);
        end

        function testSf12SourceProfileExplainsFiveHundredTenHz(testCase)
            cfg = authorFigureSf12Config();
            layout = buildFrameLayout(cfg);
            frameChangeHz = abs(circularOrbitDoppler( ...
                layout.midamblePointToaS, cfg) - ...
                circularOrbitDoppler(0, cfg));
            testCase.verifyGreaterThan(frameChangeHz, 490);
            testCase.verifyLessThan(frameChangeHz, 520);
        end

        function testSf7SourceProfile(testCase)
            cfg = authorFigureSf7Config();
            testCase.verifyEqual(cfg.channel.model, "awgn_only");
            testCase.verifyEqual( ...
                cfg.frame.midambleSpacingDataSymbols, 12);
            testCase.verifyFalse(cfg.provenance.fittedOrTuned);
        end

        function testAwgnOnlyChannelIsUnity(testCase)
            cfg = authorFigureSf12Config();
            coefficient = drawChannelCoefficient(cfg, 8);
            testCase.verifyEqual(coefficient, ones(1, 8));
        end

        function testUnknownChannelRejected(testCase)
            cfg = authorFigureSf12Config();
            cfg.channel.model = "unknown";
            testCase.verifyError(@() drawChannelCoefficient(cfg, 1), ...
                'drawChannelCoefficient:UnknownModel');
        end

        function testSampleRicianShapeAndPower(testCase)
            cfg = publishedSampleRicianSf12Config();
            coefficient = drawChannelCoefficient(cfg, 10000, 4);
            testCase.verifySize(coefficient, [4, 10000]);
            testCase.verifyEqual(mean(abs(coefficient(:)).^2), ...
                1, 'AbsTol', 0.02);
        end

        function testSampleRicianSimulationPath(testCase)
            cfg = publishedSampleRicianSf7Config();
            limits = struct('batchPackets', 1, ...
                'minimumPackets', 1, 'maximumPackets', 1, ...
                'minimumSymbolErrors', 0);
            result = simulateSerPoint(cfg, "case1", ...
                "point", -6, limits);
            testCase.verifyEqual(result.packets, 1);
            testCase.verifyEqual(result.totalSymbols, ...
                cfg.frame.payloadSymbols);
            testCase.verifyFalse(result.fittedOrTuned);
        end
    end
end
