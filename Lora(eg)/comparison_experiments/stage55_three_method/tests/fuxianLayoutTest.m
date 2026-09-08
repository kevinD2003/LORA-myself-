classdef fuxianLayoutTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            comparisonRoot = fileparts(fileparts(mfilename('fullpath')));
            sourceRoot = fuxianSourceRoot(comparisonRoot);
            testCase.applyFixture(PathFixture(sourceRoot));
            testCase.applyFixture(PathFixture(comparisonRoot));
        end
    end

    methods (Test)
        function testProjectConditionsAndEquationScaling(testCase)
            experiment = fuxianComparisonConfig();
            testCase.verifyEqual(experiment.config.sf, 11);
            testCase.verifyEqual( ...
                experiment.config.bandwidthHz, 250e3);
            testCase.verifyEqual(experiment.midambleSpacing, 48);
            testCase.verifyEqual(experiment.midambleCount, 2);
            testCase.verifyEqual(experiment.trackingMidambleCount,2);
            testCase.verifyEqual(experiment.toaMidambleCount,3);
            testCase.verifyEqual(experiment.terminalMidambleCount,1);
            testCase.verifyEqual(experiment.spacingSensitivity,[48 65 81]);
            testCase.verifyFalse(experiment.fittedOrTuned);
        end

        function testStrictEquationTwentyLayout(testCase)
            experiment = fuxianComparisonConfig( ...
                MidambleSpacingMode="visible_rate_matched", ...
                IncludeTerminalMidamble=true);
            payloadBins = (0:experiment.config.payloadSymbolCount-1).';
            layout = fuxianMidambleLayout(payloadBins,experiment);
            testCase.verifyEqual(experiment.midambleSpacing,81);
            testCase.verifyEqual(experiment.trackingMidambleCount,1);
            testCase.verifyEqual(experiment.toaMidambleCount,2);
            testCase.verifyEqual(layout.trackingMidambleAfterDataIndex,81);
            testCase.verifyEqual(layout.midambleAfterDataIndex,[81;112]);
            testCase.verifyEqual(layout.terminalMidambleRows,122);
            testCase.verifyEqual(layout.physicalSymbolCount,122);
        end

        function testPhysicalLayoutRetainsEveryDataSymbol(testCase)
            experiment = fuxianComparisonConfig();
            payloadBins = (0:experiment.config.payloadSymbolCount-1).';
            layout = fuxianMidambleLayout(payloadBins,experiment);
            testCase.verifyEqual(layout.physicalSymbolCount, 122);
            testCase.verifyEqual(layout.midambleRows, [57;106]);
            testCase.verifyEqual(layout.midambleAfterDataIndex, [48;96]);
            testCase.verifyEqual( ...
                layout.physicalBins(layout.dataRows),payloadBins);
            testCase.verifyEqual( ...
                layout.physicalBins(layout.midambleRows),zeros(2,1));
        end

        function testFrameOverheadIsExplicit(testCase)
            experiment = fuxianComparisonConfig();
            layout = fuxianMidambleLayout( ...
                zeros(experiment.config.payloadSymbolCount,1),experiment);
            testCase.verifyEqual(layout.frameOverheadFraction, ...
                2/120,'AbsTol',1e-15);
            testCase.verifyEqual( ...
                experiment.physicalConfig.frameSymbolCount,122);
        end
    end
end
