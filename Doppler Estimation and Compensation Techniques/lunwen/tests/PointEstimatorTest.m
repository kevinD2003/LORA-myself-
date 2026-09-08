classdef PointEstimatorTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            import matlab.unittest.fixtures.PathFixture
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'src')));
            testCase.applyFixture(PathFixture(fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function testPositiveTenKilohertzCfo(testCase)
            cfg = paperSf12Config();
            report = validatePointEstimator(cfg);
            testCase.verifyGreaterThan(report.estimatedCfoHz, 0);
            testCase.verifyLessThanOrEqual( ...
                report.absoluteErrorHz, report.fftBinHz);
        end

        function testZeroPaddingRefinesOffGridEstimate(testCase)
            sampleRateHz = 125e3;
            sampleCount = 128;
            frequencyHz = 20.7*sampleRateHz/sampleCount;
            timeS = (0:sampleCount-1).'/sampleRateHz;
            tone = exp(1j*2*pi*frequencyHz*timeS);
            native = estimateFftFrequency(tone, sampleRateHz);
            refined = estimateFftFrequency( ...
                tone, sampleRateHz, 16*sampleCount);
            testCase.verifyLessThan(abs(refined-frequencyHz), ...
                abs(native-frequencyHz));
            testCase.verifyError(@() estimateFftFrequency( ...
                tone, sampleRateHz, sampleCount/2), ...
                'estimateFftFrequency:FftTooShort');
        end
    end
end
