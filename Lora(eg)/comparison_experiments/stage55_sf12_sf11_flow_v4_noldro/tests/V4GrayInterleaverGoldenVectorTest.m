classdef V4GrayInterleaverGoldenVectorTest < matlab.unittest.TestCase
    methods (Test)
        function independentGrayValuesMatch(testCase)
            root = v4SetupPaths();
            fixture = jsondecode(fileread(fullfile(root,'tests','fixtures', ...
                'independent_gray_interleave_vectors.json')));
            actual = double(v4GrayEncode(uint32(fixture.binaryLabels)));
            testCase.verifyEqual(actual,fixture.grayLabels);
            testCase.verifyEqual(double(v4GrayDecode(uint32(actual))), ...
                fixture.binaryLabels);
        end
        function highBitsParticipateInInterleaver(testCase)
            root = v4SetupPaths();
            fixture = jsondecode(fileread(fullfile(root,'tests','fixtures', ...
                'independent_gray_interleave_vectors.json')));
            config = sf12NoLdroSf11FlowConfig();
            for index = 1:numel(fixture.singleBitCases)
                item = fixture.singleBitCases(index);
                bits = false(12,7);
                bits(item.row,item.column) = true;
                labels = v4DiagonalInterleave(bits,config);
                testCase.verifyEqual(labels(item.column),item.expectedGrayLabel);
                testCase.verifyEqual(v4DiagonalDeinterleave(labels,config),bits);
            end
        end
    end
end
