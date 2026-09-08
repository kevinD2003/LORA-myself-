classdef PipelineIntegrationTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (TestMethodSetup)
        function setDeterministicRandomState(testCase)
            originalState = rng;
            testCase.addTeardown(@() rng(originalState));
            rng(2026, 'twister');
        end
    end

    methods (Test)
        function testPaperAgreementRejectsOutOfRangeResult(testCase)
            resultTable = table(["case1"; "case2"], ...
                ["point"; "point"], [-21; -21], [0.1; 0.7], ...
                'VariableNames', {'caseName', 'strategy', 'snrDb', 'ser'});
            referenceTable = table([12; 12], ["case1"; "case2"], ...
                ["point"; "point"], [-21; -21], ...
                [0.015; 0.55], [0.045; 0.75], ...
                'VariableNames', {'spreadingFactor', 'caseName', ...
                'strategy', 'snrDb', 'serLow', 'serHigh'});
            evaluation = evaluatePaperAgreement( ...
                resultTable, referenceTable, 12);
            testCase.verifyFalse(evaluation.passed);
            testCase.verifyEqual(evaluation.matchCount, 1);
        end

        function testInvalidCaseRejected(testCase)
            cfg = paperSf12Config();
            limits = onePacketLimits();
            testCase.verifyError(@() simulateSerPoint( ...
                cfg, "bad_case", "point", -21, limits), ...
                'simulateSerPoint:UnknownCase');
        end

        function testInvalidStrategyRejected(testCase)
            cfg = paperSf12Config();
            limits = onePacketLimits();
            testCase.verifyError(@() simulateSerPoint( ...
                cfg, "case1", "bad_strategy", -21, limits), ...
                'simulateSerPoint:UnknownStrategy');
        end

        function testInvalidLimitsRejected(testCase)
            cfg = paperSf12Config();
            limits = struct('batchPackets', 0, 'minimumPackets', 1, ...
                'maximumPackets', 1, 'minimumSymbolErrors', 0);
            testCase.verifyError(@() simulateSerPoint( ...
                cfg, "case1", "point", -21, limits), ...
                'simulateSerPoint:InvalidLimits');
        end

        function testUnknownMidambleEstimatorModelRejected(testCase)
            cfg = paperSf12Config();
            cfg.receiver.midambleEstimatorModel = "unknown";
            template = complex(ones(cfg.radio.samplesPerSymbol, 1));
            testCase.verifyError(@() estimateResidualBatch( ...
                template, 1, 0, -21, cfg), ...
                'estimateResidualBatch:UnknownEstimatorModel');
        end

        function testNonLdroDetectorPath(testCase)
            cfg = paperSf7Config();
            template = complex(ones(cfg.radio.samplesPerSymbol, 1));
            errors = detectZeroSymbolBatch(template, 1, 0, 100, cfg);
            testCase.verifyEqual(errors, 0);
        end

        function testLdroDecisionModes(testCase)
            cfg = paperSf12Config();
            template = complex(ones(cfg.radio.samplesPerSymbol, 1));
            cfg.radio.ldroDecisionMode = "peak_quantize";
            peakErrors = detectZeroSymbolBatch( ...
                template, 1, 0, 100, cfg);
            cfg.radio.ldroDecisionMode = "valid_bins_only";
            validErrors = detectZeroSymbolBatch( ...
                template, 1, 0, 100, cfg);
            testCase.verifyEqual(peakErrors, 0);
            testCase.verifyEqual(validErrors, 0);
            cfg.radio.ldroDecisionMode = "unsupported";
            testCase.verifyError(@() detectZeroSymbolBatch( ...
                template, 1, 0, 100, cfg), ...
                'detectZeroSymbolBatch:UnknownLdroDecisionMode');
        end

        function testExplicitLdroModePreservesLegacyResults(testCase)
            explicitCfg = paperSf12Config();
            legacyCfg = explicitCfg;
            legacyCfg.radio = rmfield( ...
                legacyCfg.radio, 'ldroDecisionMode');
            limits = struct('batchPackets', 4, 'minimumPackets', 4, ...
                'maximumPackets', 4, 'minimumSymbolErrors', 0);
            for caseName = ["case1", "case2"]
                for strategy = ["no_doppler", "point", ...
                        "midamble_point"]
                    explicitResult = simulateSerPoint(explicitCfg, ...
                        caseName, strategy, -21, limits);
                    legacyResult = simulateSerPoint(legacyCfg, ...
                        caseName, strategy, -21, limits);
                    testCase.verifyEqual(explicitResult.symbolErrors, ...
                        legacyResult.symbolErrors);
                    testCase.verifyEqual(explicitResult.totalSymbols, ...
                        legacyResult.totalSymbols);
                end
            end
        end

        function testAwgnAlwaysProducesComplexBaseband(testCase)
            cfg = paperSf7Config();
            [received, ~] = applyUnitPowerAwgn(ones(128, 1), -6, cfg);
            testCase.verifyTrue(~isreal(received));
            testCase.verifyGreaterThan(norm(imag(received)), 0);
        end

        function testRunReproductionCaseWritesCsvAndFigures(testCase)
            cfg = paperSf7Config();
            limits = onePacketLimits();
            outputFolder = createTemporaryFolder(testCase);
            resultTable = runReproductionCase(cfg, "case1", -6, ...
                limits, outputFolder, "_integration");
            testCase.verifyEqual(height(resultTable), 3);
            testCase.verifyTrue(isfile(fullfile(outputFolder, ...
                'case1_sf7_integration.csv')));
            testCase.verifyTrue(isfile(fullfile(outputFolder, ...
                'case1_sf7_integration.png')));
            testCase.verifyTrue(isfile(fullfile(outputFolder, ...
                'case1_sf7_integration.fig')));
        end

        function testTrackingWriterAndPlotter(testCase)
            cfg = paperSf7Config();
            trace = buildTrackingTrace(cfg, "case2");
            outputFolder = createTemporaryFolder(testCase);
            csvPath = fullfile(outputFolder, 'tracking.csv');
            pngPath = fullfile(outputFolder, 'tracking.png');
            traceTable = writeTrackingTrace(trace, csvPath);
            plotTrackingTrace(trace, pngPath);
            testCase.verifyEqual(height(traceTable), cfg.frame.payloadSymbols);
            testCase.verifyTrue(isfile(csvPath));
            testCase.verifyTrue(isfile(pngPath));
        end

        function testFigureCombiner(testCase)
            outputFolder = createTemporaryFolder(testCase);
            firstPath = fullfile(outputFolder, 'first.png');
            secondPath = fullfile(outputFolder, 'second.png');
            combinedPath = fullfile(outputFolder, 'combined.png');
            imwrite(uint8(zeros(10, 12, 3)), firstPath);
            imwrite(uint8(255*ones(10, 12, 3)), secondPath);
            combineCaseFigureFiles(firstPath, secondPath, combinedPath);
            combined = imread(combinedPath);
            testCase.verifySize(combined, [10, 24, 3]);
        end

        function testRicianUnitAveragePower(testCase)
            coefficient = ricianBlockCoefficient(200000, 10);
            measuredPower = mean(abs(coefficient).^2);
            testCase.verifyEqual(measuredPower, 1, 'AbsTol', 0.01);
        end

        function testCoherenceDiagnosticPaths(testCase)
            cfg = paperSf7Config();
            packetResult = simulateNoDopplerCoherence( ...
                cfg, -6, 2, "packet");
            symbolResult = simulateNoDopplerCoherence( ...
                cfg, -6, 2, "symbol");
            testCase.verifyEqual(packetResult.totalSymbols, 66);
            testCase.verifyEqual(symbolResult.totalSymbols, 66);
        end

        function testMonteCarloLimitModes(testCase)
            cfg = paperSf12Config();
            fullLimits = monteCarloLimits(cfg, "full");
            smokeLimits = monteCarloLimits(cfg, "smoke");
            testCase.verifyEqual(fullLimits.minimumPackets, 5000);
            testCase.verifyEqual(smokeLimits.minimumPackets, 16);
        end

        function testFrameProtocolDistinguishesResolvedAndUnresolved(testCase)
            sf7Report = validateFrameProtocol(paperSf7Config());
            sf12Report = validateFrameProtocol(paperSf12Config());
            testCase.verifyTrue(sf7Report.passed);
            testCase.verifyFalse(sf12Report.passed);
            testCase.verifyEqual(sf12Report.status, ...
                "paper_table_fractional_midamble_conflict");
            testCase.verifyTrue(sf12Report.implementationProtocolPassed);
            testCase.verifyTrue(sf12Report.paperInternalConflictProved);
        end

        function testIndependentSeedModeIncludesSpreadingFactor(testCase)
            sf11 = paperSf11Config();
            sf12 = paperSf12Config();
            sf11.monteCarlo.commonRandomNumbersAcrossSf = false;
            sf12.monteCarlo.commonRandomNumbersAcrossSf = false;
            sf11Seed = seedForRun(sf11, "case1", "point", -21);
            sf12Seed = seedForRun(sf12, "case1", "point", -21);
            testCase.verifyNotEqual(sf11Seed, sf12Seed);
        end

        function testPairedStrategyRandomNumbers(testCase)
            cfg = calibratedPaperSf7Config();
            pointSeed = seedForRun(cfg, "case1", "point", -6);
            midambleSeed = seedForRun( ...
                cfg, "case1", "midamble_point", -6);
            testCase.verifyEqual(pointSeed, midambleSeed);

            cfg.frame.midambleSpacingDataSymbols = ...
                cfg.frame.payloadSymbols + 1;
            cfg.frame.insertAfterFinalPartialBlock = false;
            limits = struct('batchPackets', 16, ...
                'minimumPackets', 32, 'maximumPackets', 32, ...
                'minimumSymbolErrors', 0);
            point = simulateSerPoint( ...
                cfg, "case1", "point", -10, limits);
            midamble = simulateSerPoint( ...
                cfg, "case1", "midamble_point", -10, limits);
            testCase.verifyEqual(point.symbolErrors, ...
                midamble.symbolErrors);
        end

        function testTerminalPilotDoesNotAlterPayloadSer(testCase)
            withTerminalPilot = paperSf12Config();
            withoutTerminalPilot = withTerminalPilot;
            withoutTerminalPilot.frame.insertAfterFinalPartialBlock = false;
            limits = struct('batchPackets', 4, 'minimumPackets', 4, ...
                'maximumPackets', 4, 'minimumSymbolErrors', 0);
            withResult = simulateSerPoint(withTerminalPilot, ...
                "case2", "midamble_point", -21, limits);
            withoutResult = simulateSerPoint(withoutTerminalPilot, ...
                "case2", "midamble_point", -21, limits);
            testCase.verifyEqual(withResult.symbolErrors, ...
                withoutResult.symbolErrors);
            testCase.verifyEqual(withResult.totalSymbols, ...
                withoutResult.totalSymbols);
        end
    end
end

function limits = onePacketLimits()
limits = struct('batchPackets', 1, 'minimumPackets', 1, ...
    'maximumPackets', 1, 'minimumSymbolErrors', 0);
end

function folder = createTemporaryFolder(testCase)
folder = string(tempname);
mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
end
