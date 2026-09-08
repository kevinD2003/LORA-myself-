classdef LoRaPhyTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testKnownSymbolRoundTrip(testCase)
            waveform = loraModulateSymbol(1234, 12);
            detected = loraDetectSymbol(waveform, 12);
            testCase.verifyEqual(detected, 1234);
        end

        function testUnitAveragePower(testCase)
            waveform = loraModulateSymbol(1234, 12);
            averagePower = mean(abs(waveform).^2);
            testCase.verifyEqual(averagePower, 1, 'AbsTol', 1e-12);
        end

        function testTenThousandRandomSymbols(testCase)
            cfg = paperSf12Config();
            report = validateLoraNoiseless(cfg, 10000);
            testCase.verifyEqual(report.symbolErrors, 0);
        end
    end
end
