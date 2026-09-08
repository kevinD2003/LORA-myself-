classdef fuxianReportTest < matlab.unittest.TestCase
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
        function testOnlySerAndBerPrimaryFigures(testCase)
            source = localReport();
            testCase.verifyEqual(height(source.figureManifest),2);
            testCase.verifyEqual(string(source.figureManifest.metric), ...
                ["SER";"Delivered BER"]);
            testCase.verifyTrue(all(isfile(string( ...
                source.figureManifest.pngFile))));
        end

        function testThreeMethodsAppearInStatistics(testCase)
            source = localReport();
            methods = sort(unique(string( ...
                source.windowStatistics.method)));
            expected = sort(["Huang-PREC-CP"; ...
                "Stage55-VP-quality";"Paper-Midamble-Point"]);
            testCase.verifyEqual(methods,expected);
        end

        function testWindowCountsArePhysical(testCase)
            source = localReport();
            testCase.verifyGreaterThan( ...
                min(source.windowStatistics.symbolCount),0);
            testCase.verifyGreaterThan( ...
                min(source.windowStatistics.bitCount),0);
            testCase.verifyLessThanOrEqual( ...
                source.windowStatistics.symbolErrors, ...
                source.windowStatistics.symbolCount);
            testCase.verifyLessThanOrEqual( ...
                source.windowStatistics.deliveredBitErrors, ...
                source.windowStatistics.bitCount);
        end

        function testTrajectoryColumnsMatchMetricRegions(testCase)
            sourceText = fileread(which( ...
                'fuxianPlotTrajectoryComparison'));
            ratePosition = strfind(sourceText, ...
                'rateAxes = nexttile(layout);');
            shiftPosition = strfind(sourceText, ...
                'shiftAxes = nexttile(layout);');
            testCase.verifyNumElements(ratePosition,1);
            testCase.verifyNumElements(shiftPosition,1);
            testCase.verifyLessThan(ratePosition,shiftPosition, ...
                ['左列必须先绘制Doppler rate，使其对应下方' ...
                'high_doppler_rate区域。']);
        end
    end
end

function source = localReport()
comparisonRoot = fileparts(fileparts(mfilename('fullpath')));
source = load(fullfile(comparisonRoot,'results','smoke_report', ...
    'sf11_stage55_three_method_report.mat'));
end
