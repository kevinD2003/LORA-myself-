classdef V4NoLdroDimensionTest < matlab.unittest.TestCase
    methods (Test)
        function identityAndDirectLabels(testCase)
            config = sf12NoLdroSf11FlowConfig();
            testCase.verifyEqual([config.physicalSf config.effectiveDataSf],[12 12]);
            testCase.verifyEqual([config.dataAlphabetSize config.dataBinSpacing],[4096 1]);
            testCase.verifyEqual([config.informationBitCount config.payloadSymbolCount],[768 112]);
            testCase.verifyEqual([config.paperMidambleCount config.commonTimelineSymbolCount],[37 157]);
            labels = [1 2 3 1023 4095];
            for label = labels
                result = v4SymbolLikelihood(v4ModulateSymbol(label,config),config,1);
                testCase.verifyEqual(result.physicalBin,label);
            end
        end
        function allLabelsRoundTrip(testCase)
            config = sf12NoLdroSf11FlowConfig();
            for label = 0:4095
                waveform = v4ModulateSymbol(label,config);
                result = v4SymbolLikelihood(waveform,config,1);
                testCase.verifyEqual(result.physicalBin,label);
            end
        end
        function maximumTieUsesSmallestLabel(testCase)
            config = sf12NoLdroSf11FlowConfig();
            mixed = v4ModulateSymbol(2,config)+v4ModulateSymbol(3,config);
            result = v4SymbolLikelihood(mixed,config,1);
            testCase.verifyEqual(result.physicalBin,2);
        end
    end
end
