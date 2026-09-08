classdef Sf11DerivationTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testEquationNineteenScaling(testCase)
            cfg = paperSf12Config();
            result = deriveMidambleSpacing(11, 12, 3, cfg);
            testCase.verifyEqual(result.scaleFactor, 4);
            testCase.verifyEqual(result.exactSpacing, 12);
            testCase.verifyEqual(result.selectedIntegerSpacing, 12);
            testCase.verifyFalse(result.fittedOrTuned);
        end

        function testPayloadSymbolFormulaAcrossSf(testCase)
            sf7 = loraPayloadSymbolCount(120, 7, 1, ...
                false, true, false);
            sf11 = loraPayloadSymbolCount(120, 11, 1, ...
                true, true, false);
            sf12 = loraPayloadSymbolCount(120, 12, 1, ...
                true, true, false);
            testCase.verifyEqual([sf7, sf11, sf12], [33, 28, 23]);
        end

        function testDerivedConfiguration(testCase)
            cfg = paperSf11Config();
            layout = buildFrameLayout(cfg);
            testCase.verifyEqual(cfg.radio.spreadingFactor, 11);
            testCase.verifyTrue(cfg.radio.ldro);
            testCase.verifyEqual(cfg.radio.dataAlphabetSize, 512);
            testCase.verifyEqual(cfg.radio.dataBinSpacing, 4);
            testCase.verifyEqual(layout.payloadSymbols, 28);
            testCase.verifyEqual(layout.numberOfMidambles, 3);
            testCase.verifyEqual(find( ...
                layout.slotKind == "midamble"), [13 26 31]);
        end

        function testCalibratedSf11Interpolation(testCase)
            cfg = calibratedPaperSf11Config();
            testCase.verifyEqual(cfg.channel.ricianKDb, 12.75);
            testCase.verifyEqual( ...
                cfg.receiver.estimatorFftPaddingFactor, 4);
            testCase.verifyEqual( ...
                cfg.receiver.midambleEstimatorFftPaddingFactor, 1);
            testCase.verifyEqual( ...
                cfg.receiver.midambleUpdateDelayDataSymbols, 1);
            testCase.verifyEqual( ...
                cfg.receiver.midambleEstimatorSnrOffsetDb, -0.30, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual( ...
                cfg.frame.midambleSpacingDataSymbols, 12);
            testCase.verifyEqual( ...
                cfg.orbit.frameDopplerTimeScale, 1);
            testCase.verifyTrue( ...
                cfg.monteCarlo.commonRandomNumbersAcrossStrategies);
            testCase.verifyTrue(cfg.provenance.fittedOrTuned);
        end

        function testDerivedTimeOnAir(testCase)
            cfg = paperSf11Config();
            layout = buildFrameLayout(cfg);
            testCase.verifyEqual(layout.pointToaS, ...
                0.626688, 'AbsTol', 1e-12);
            testCase.verifyEqual(layout.midamblePointToaS, ...
                0.67584, 'AbsTol', 1e-12);
        end

        function testSNRGridEndsNearFifteenDbEsN0(testCase)
            cfg = paperSf11Config();
            endEsN0Db = cfg.monteCarlo.snrDb(end) + ...
                10*log10(cfg.radio.samplesPerSymbol);
            testCase.verifyEqual(endEsN0Db, ...
                15.1132995230379, 'AbsTol', 1e-10);
        end
    end
end
