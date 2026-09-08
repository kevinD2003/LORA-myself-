classdef V4IndependentChirpGoldenVectorTest < matlab.unittest.TestCase
    methods (Test)
        function independentFormulaHitsExpectedBins(testCase)
            root = v4SetupPaths();
            fixture = jsondecode(fileread(fullfile(root,'tests','fixtures', ...
                'independent_chirp_vectors.json')));
            config = sf12NoLdroSf11FlowConfig();
            m = 4096;
            n = (0:m-1).';
            independentDownchirp = exp(-1i*2*pi*(n.^2/(2*m)-n/2));
            for index = 1:numel(fixture.labels)
                s = fixture.labels(index);
                independent = exp(1i*2*pi*(n.^2/(2*m)-n/2+s*n/m));
                spectrum = fft(independent.*independentDownchirp);
                [~,bin] = max(abs(spectrum).^2);
                testCase.verifyEqual(bin-1,fixture.expectedFftBins(index));
                decision = v4SymbolLikelihood(independent.',config,1);
                testCase.verifyEqual(decision.physicalBin,s);
            end
        end
    end
end
