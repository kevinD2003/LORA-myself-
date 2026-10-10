classdef DrePaperReproductionTest < matlab.unittest.TestCase
    methods(Test)
        function orbitMatchesPublishedWorstCase(testCase)
            c = drePaperConfig();
            zero = drePaperOrbit(0,c);
            t = linspace(-zero.horizonTimeSec,zero.horizonTimeSec,20001);
            orbit = drePaperOrbit(t,c);
            testCase.verifyEqual(max(abs(orbit.dopplerHz))/1e3,50.5,'AbsTol',0.8);
            testCase.verifyEqual(max(abs(orbit.dopplerRateHzPerSec)),970,'AbsTol',25);
        end

        function centroidRecoversNoiseFreeSymbols(testCase)
            c = drePaperConfig();
            symbols = [0;1;17;2048;4095];
            estimate = dreEstimateCentroids(dreModulateSymbols(symbols,c),c);
            error = dreCircularSymbolDistance(estimate.rawBins,symbols,c.samplesPerSymbol);
            testCase.verifyLessThan(max(error),0.02);
        end

        function tenPointCentroidUsesPaperCount(testCase)
            c = drePaperConfig();
            symbols = [0;1;17;2048;4095];
            estimate = dreEstimatePaperCentroids10( ...
                dreModulateSymbols(symbols,c),c);
            error = dreCircularSymbolDistance( ...
                estimate.rawBins,symbols,c.samplesPerSymbol);
            testCase.verifyEqual(numel(estimate.offsets),10);
            testCase.verifyLessThan(max(error),0.1);
        end

        function linearRegressionUsesNoPayloadTruth(testCase)
            c = drePaperConfig();
            symbols = [zeros(c.preambleSymbolCount,1); ...
                mod((100:100+c.payloadSymbolCount-1).',c.samplesPerSymbol)];
            x = (0:numel(symbols)-1).';
            raw = mod(symbols+12.25+0.2*x,c.samplesPerSymbol);
            fixed = dreDecodeLinearRegression(raw,zeros(c.preambleSymbolCount,1),c,'fixed');
            adaptive = dreDecodeLinearRegression(raw,zeros(c.preambleSymbolCount,1),c,'adaptive');
            testCase.verifyEqual(fixed.detectedSymbols,symbols(c.preambleSymbolCount+1:end));
            testCase.verifyEqual(adaptive.detectedSymbols,symbols(c.preambleSymbolCount+1:end));
            testCase.verifyFalse(fixed.usesPayloadTruth);
            testCase.verifyFalse(adaptive.usesPayloadTruth);
        end

        function circularBoundaryIsExplicit(testCase)
            c = drePaperConfig();
            symbols = [zeros(c.preambleSymbolCount,1);0;0];
            raw = symbols;
            raw(c.preambleSymbolCount+1) = c.samplesPerSymbol-0.2;
            raw(c.preambleSymbolCount+2) = 0.2;
            decoded = dreDecodeLinearRegression(raw, ...
                zeros(c.preambleSymbolCount,1),c,'fixed');
            testCase.verifyEqual(decoded.detectedSymbols,[0;0]);
        end

        function paperPacketSmoke(testCase)
            c = drePaperConfig();
            packet = dreGeneratePaperPacket(0,Inf,c.randomSeed,c);
            estimate = dreEstimateCentroids(packet.rx,c);
            decoded = dreDecodeLinearRegression(estimate.rawBins, ...
                packet.symbols(1:c.preambleSymbolCount),c,'adaptive');
            testCase.verifySize(decoded.detectedSymbols,[c.payloadSymbolCount 1]);
            testCase.verifyFalse(decoded.usesPayloadTruth);
        end

        function fullPhyRoundTripCr1AndCr4(testCase)
            c = dreFullPhyConfig();
            for cr = [1 4]
                stream = RandStream('mt19937ar','Seed',100+cr);
                payload = dreGenerateFullPhyPayload(8,cr,c,stream);
                decoded = dreDecodeFullPhyPayload(payload.logicalBins,payload,cr,c);
                testCase.verifyTrue(all(decoded.crcPass));
                testCase.verifyEqual(decoded.codedErrorCount,zeros(1,8));
                testCase.verifyEqual(decoded.payloadBits,payload.payloadBits);
            end
        end

        function fullPhyCodeMinimumDistance(testCase)
            expected = [2 4];
            for index = 1:2
                cr = [1 4];
                book = dreFullPhyCodebook(cr(index));
                distances = inf(16);
                for a = 1:16
                    for b = a+1:16
                        distances(a,b) = sum(book.code(a,:)~=book.code(b,:));
                    end
                end
                testCase.verifyEqual(min(distances,[],'all'),expected(index));
                testCase.verifyGreaterThanOrEqual(min(sum(book.code(2:end,:),2)), ...
                    expected(index));
            end
        end

        function grayRoundTrip(testCase)
            values = uint32((0:4095).');
            testCase.verifyEqual(dreGrayDecode(dreGrayEncode(values)),values);
        end

        function batchAndScalarLrAgree(testCase)
            c = drePaperConfig();
            stream = RandStream('mt19937ar','Seed',44);
            symbols = [zeros(c.preambleSymbolCount,3); ...
                randi(stream,[0 c.samplesPerSymbol-1],12,3)];
            x = (0:size(symbols,1)-1).';
            raw = mod(symbols+15+0.3*x,c.samplesPerSymbol);
            batch = dreDecodeLinearRegressionBatch(raw,c.preambleSymbolCount, ...
                c.samplesPerSymbol,'adaptive');
            for replicate = 1:3
                scalar = dreDecodeLinearRegression(raw(:,replicate), ...
                    zeros(c.preambleSymbolCount,1),c,'adaptive');
                testCase.verifyEqual(batch.detectedSymbols(:,replicate), ...
                    scalar.detectedSymbols);
            end
        end
    end
end
