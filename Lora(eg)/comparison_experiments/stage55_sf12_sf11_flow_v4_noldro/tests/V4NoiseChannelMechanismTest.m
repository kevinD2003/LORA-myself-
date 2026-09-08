classdef V4NoiseChannelMechanismTest < matlab.unittest.TestCase
    methods (Test)
        function ricianAndComplexNoiseMoments(testCase)
            config = sf12NoLdroSf11FlowConfig();
            count = 100000;
            h = v4RicianCoefficient(config,410000001,count);
            testCase.verifyLessThan(abs(mean(abs(h).^2)-1),0.02);
            stream = RandStream('mt19937ar','Seed',410000002);
            noise = (randn(stream,count,1)+1i*randn(stream,count,1))/sqrt(2);
            testCase.verifyLessThan(abs(mean(real(noise))),0.02);
            testCase.verifyLessThan(abs(mean(imag(noise))),0.02);
            testCase.verifyLessThan(abs(mean(abs(noise).^2)-1),0.02);
            testCase.verifyLessThan(abs(var(real(noise),1)-0.5),0.02);
            testCase.verifyLessThan(abs(var(imag(noise),1)-0.5),0.02);
        end
    end
end
