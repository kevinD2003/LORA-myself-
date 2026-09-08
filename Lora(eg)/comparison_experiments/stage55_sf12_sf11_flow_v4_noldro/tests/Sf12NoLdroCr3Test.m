classdef Sf12NoLdroCr3Test < matlab.unittest.TestCase
    properties
        Config
    end
    methods (TestMethodSetup)
        function buildConfig(testCase)
            testCase.Config = sf12NoLdroSf11FlowConfig();
        end
    end
    methods (Test)
        function identityIsFrozen(testCase)
            c = testCase.Config;
            testCase.verifyEqual(c.physicalSf,12);
            testCase.verifyEqual(c.effectiveDataSf,12);
            testCase.verifyEqual(c.dataAlphabetSize,4096);
            testCase.verifyEqual(c.dataBinSpacing,1);
            testCase.verifyEqual(c.payloadSymbolCount,112);
            testCase.verifyEqual(c.informationBitCount,768);
            testCase.verifyFalse(c.usesOrbitPrior);
        end
        function everyLegalLabelRoundTrips(testCase)
            c = testCase.Config;
            for logicalBin = 0:c.dataAlphabetSize-1
                physicalBin = logicalBin*c.dataBinSpacing;
                waveform = v4ModulateSymbol(physicalBin,c);
                decision = v4SymbolLikelihood(waveform,c);
                [~,softMap] = max(decision.logProbability);
                testCase.verifyEqual(decision.logicalBin,logicalBin);
                testCase.verifyEqual(decision.physicalBin,physicalBin);
                testCase.verifyEqual(softMap-1,logicalBin);
            end
        end
        function hammingTableMatchesSf11Definition(testCase)
            table = v4Hamming74Table();
            testCase.verifySize(table,[16 7]);
            testCase.verifyEqual(size(unique(table,'rows'),1),16);
            for value = 0:15
                data = bitget(uint32(value),4:-1:1) ~= 0;
                parity = mod([double(data(1))+double(data(2))+double(data(4)), ...
                    double(data(1))+double(data(3))+double(data(4)), ...
                    double(data(2))+double(data(3))+double(data(4))],2) ~= 0;
                testCase.verifyEqual(table(value+1,:),[data parity]);
            end
        end
        function randomBlocksHardSoftRoundTrip(testCase)
            c = testCase.Config;
            payload = v4GeneratePayload(c,c.seeds.mechanismPayloadBase+1);
            rx = complex(zeros(c.payloadSymbolCount,c.samplesPerSymbol));
            for row = 1:c.payloadSymbolCount
                rx(row,:) = v4ModulateSymbol(payload.physicalBins(row),c);
            end
            decoded = v4DecodePayload(rx,c);
            testCase.verifyEqual(decoded.hardLogicalBins,payload.logicalBins);
            testCase.verifyEqual(decoded.softMapLogicalBins,payload.logicalBins);
            testCase.verifyEqual(decoded.hardDataBits,logical(payload.dataBits));
            testCase.verifyEqual(decoded.softDataBits,logical(payload.dataBits));
            testCase.verifyEqual(mod(payload.physicalBins,c.dataBinSpacing), ...
                zeros(c.payloadSymbolCount,1));
            testCase.verifyLessThan(max(payload.logicalBins),c.dataAlphabetSize);
            testCase.verifySize(payload.codedBits,[12 7 16]);
        end
        function noNoiseMetricsAreZero(testCase)
            c = testCase.Config;
            payload = v4GeneratePayload(c,c.seeds.mechanismPayloadBase+2);
            rx = complex(zeros(c.payloadSymbolCount,c.samplesPerSymbol));
            for row = 1:c.payloadSymbolCount
                rx(row,:) = v4ModulateSymbol(payload.physicalBins(row),c);
            end
            decoded = v4DecodePayload(rx,c);
            ser = mean(decoded.hardPhysicalBins ~= payload.physicalBins);
            hardBer = mean(decoded.hardDataBits(:) ~= logical(payload.dataBits(:)));
            softBer = mean(decoded.softDataBits(:) ~= logical(payload.dataBits(:)));
            per = double(any(decoded.softDataBits(:) ~= logical(payload.dataBits(:))));
            testCase.verifyEqual([ser hardBer softBer per],[0 0 0 0]);
        end
    end
end
