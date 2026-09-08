classdef testSenLoRaConfidence < matlab.unittest.TestCase
    %TESTSENLORACONFIDENCE Unit tests for SenLoRa confidence reproduction.

    methods (TestMethodSetup)
        function preserveRandomState(testCase)
            previousState = rng;
            testCase.addTeardown(@()rng(previousState));
        end
    end

    methods (Test)
        function grayMappingSf3(testCase)
            testGrayMappingSf3(testCase);
        end

        function softHammingDecodeCr3(testCase)
            testSoftHammingDecodeCr3(testCase);
        end

        function endToEndConfidenceDetection(testCase)
            testEndToEndConfidenceDetection(testCase);
        end

        function continuousSequenceFlagsAndPendingTail(testCase)
            testContinuousSequenceFlagsAndPendingTail(testCase);
        end

        function loRaWaveformFrontEnd(testCase)
            testLoRaWaveformFrontEnd(testCase);
        end

        function phaseRotationResidualEstimator(testCase)
            testPhaseRotationResidualEstimator(testCase);
        end

        function predictiveDopplerNoiseFree(testCase)
            testPredictiveDopplerNoiseFree(testCase);
        end

        function theoreticalBerMonotonic(testCase)
            testTheoreticalBerMonotonic(testCase);
        end

        function sf11PhysicalDopplerBoundary(testCase)
            testSf11PhysicalDopplerBoundary(testCase);
        end

        function variableDopplerRateIntegration(testCase)
            testVariableDopplerRateIntegration(testCase);
        end

        function quadraticPredictorNoiseFree(testCase)
            testQuadraticPredictorNoiseFree(testCase);
        end

        function blockConfidenceThreshold(testCase)
            testBlockConfidenceThreshold(testCase);
        end
    end
end

function testGrayMappingSf3(testCase)
expected = logical([ ...
    1 0 0; ...
    0 0 0; ...
    0 0 1; ...
    0 1 1; ...
    0 1 0; ...
    1 1 0; ...
    1 1 1; ...
    1 0 1]);

verifyEqual(testCase, loraGrayBits(3), expected);

end

function testSoftHammingDecodeCr3(testCase)
cr = 3;
table = hammingCodeTable(cr);
bits = false(numel(table), 4 + cr);
for idx = 1:numel(table)
    bits(idx, :) = codewordBits(table(idx), cr);
end
% Pick nibble 6. Positive LLR means bit=1; negative means bit=0.
targetNibble = 6;
targetBits = bits(targetNibble + 1, :);
llr = 8 * (2 * double(targetBits) - 1);

[decodedBits, decodedNibble, score] = softHammingDecodeOne(llr, cr);

verifyEqual(testCase, decodedBits, targetBits);
verifyEqual(testCase, decodedNibble, targetNibble);
verifyGreaterThan(testCase, score, 0);
verifySize(testCase, bits, [16 7]);

end

function testEndToEndConfidenceDetection(testCase)
cfg.sf = 7;
cfg.cr = 3;
cfg.alpha = 0.8;
cfg.probMode = "paper";
cfg.amendMode = "identity";
cfg.thresholdMode = "global";

rng(11);
dataNibbles = randi([0 15], cfg.sf, 1);
targetBins = nibblesToDemoBins(dataNibbles, cfg);
symbolSnrDb = [18 17 7 16 5 15 6]';
[payloadFft, preambleFft] = synthesizeDemoSpectra(targetBins, cfg.sf, symbolSnrDb);

result = detectConfidentSymbolsFromFft(payloadFft, preambleFft, cfg, []);

verifyGreaterThanOrEqual(testCase, numel(result.confidentIdx), 1);
verifyLessThan(testCase, numel(result.confidentIdx), cfg.cr + 4);
verifyEqual(testCase, size(result.llrSymbols), [cfg.cr + 4 cfg.sf]);

end

function testContinuousSequenceFlagsAndPendingTail(testCase)
cfg.sf = 7;
cfg.cr = 3;
cfg.alpha = 0.8;
cfg.probMode = "paper";
cfg.amendMode = "identity";
cfg.thresholdMode = "global";

rng(41);
blockSize = 4 + cfg.cr;
numCompleteBlocks = 3;
numTailSymbols = 2;
targetBins = zeros(numCompleteBlocks * blockSize + numTailSymbols, 1);

for blockIdx = 1:(numCompleteBlocks + 1)
    dataNibbles = randi([0 15], cfg.sf, 1);
    blockBins = nibblesToDemoBins(dataNibbles, cfg);
    firstIndex = (blockIdx - 1) * blockSize + 1;
    lastIndex = min(blockIdx * blockSize, numel(targetBins));
    targetBins(firstIndex:lastIndex) = ...
        blockBins(1:(lastIndex - firstIndex + 1));
end

symbolSnrDb = 16 * ones(size(targetBins));
forcedErrorIdx = [4 12];
symbolSnrDb(forcedErrorIdx) = -10;
[payloadFft, preambleFft] = synthesizeDemoSpectra( ...
    targetBins, cfg.sf, symbolSnrDb);

numBins = 2 ^ cfg.sf;
for idx = forcedErrorIdx
    wrongBin = mod(targetBins(idx) + 19, numBins);
    payloadFft(idx, wrongBin + 1) = max(abs(payloadFft(idx, :))) + 1;
end

result = detectContinuousSymbolSequence( ...
    payloadFft, preambleFft, cfg, targetBins);

verifyTrue(testCase, all(result.errorFlag(forcedErrorIdx)));
verifyTrue(testCase, all(~result.correctFlag(forcedErrorIdx)));
verifyEqual(testCase, result.correctFlag, ~result.errorFlag);
verifyEqual(testCase, result.numCompletedBlocks, numCompleteBlocks);
verifyEqual(testCase, result.numPendingSymbols, numTailSymbols);
verifyTrue(testCase, all(result.confidenceReadyFlag(1:(3 * blockSize))));
verifyTrue(testCase, all(~result.confidenceReadyFlag(end - 1:end)));
verifyEqual(testCase, result.receiverDecisionFlag(end - 1:end), int8([0; 0]));

end

function testLoRaWaveformFrontEnd(testCase)
cfg.sf = 7;
cfg.cr = 3;
cfg.alpha = 0.8;
cfg.probMode = "paper";
cfg.amendMode = "identity";
cfg.thresholdMode = "global";
cfg.preambleSymbols = 8;
cfg.preambleSnrDb = 35;

rng(53);
dataNibbles = randi([0 15], cfg.sf, 1);
targetBins = nibblesToDemoBins(dataNibbles, cfg);
symbolSnrDb = 35 * ones(size(targetBins));
[rxSignal, ~] = synthesizeLoRaSignalSequence( ...
    targetBins, cfg, symbolSnrDb);

[result, frontend] = detectLoRaSignalSequence( ...
    rxSignal, cfg, numel(targetBins), targetBins);

verifyEqual(testCase, result.detectedBins, targetBins);
verifyTrue(testCase, all(result.correctFlag));
verifyFalse(testCase, any(result.errorFlag));
verifySize(testCase, frontend.payloadFft, ...
    [numel(targetBins), 2 ^ cfg.sf]);

end

function testPhaseRotationResidualEstimator(testCase)
sf = 7;
trueBin = 43;
trueOffset = 0.37;
sampleIndex = 0:(2 ^ sf - 1);
samples = modulateLoRaSymbol(trueBin, sf) .* ...
    exp(1i * 2 * pi * trueOffset * sampleIndex / (2 ^ sf));
offsets = (-0.5:0.1:0.5).';
estimate = estimateResidualByPhaseRotation( ...
    samples, trueBin, sf, offsets, makePhaseRotationBank(sf, offsets));

verifyLessThan(testCase, abs(estimate - trueOffset), 0.02);

end

function testPredictiveDopplerNoiseFree(testCase)
cfg.sf = 7;
cfg.bootstrapPilotCount = 3;
cfg.historyLength = 6;
cfg.initialSearchOffsets = (-1:0.1:1).';
cfg.residualSearchOffsets = (-0.5:0.1:0.5).';

rng(61);
numSymbols = 36;
symbolIndex = (0:(numSymbols - 1)).';
trueCfo = 0.22 + 0.012 * symbolIndex;
trueBins = randi([0 2 ^ cfg.sf - 1], numSymbols, 1);
[~, txSymbols] = generateDopplerLoRaSymbols( ...
    trueBins, cfg.sf, trueCfo, 100);
result = predictiveDopplerCompensate(txSymbols, trueBins, cfg);

verifyEqual(testCase, result.detectedBins, trueBins);
verifyTrue(testCase, all(result.correctFlag));
verifyTrue(testCase, all(result.pilotUpdateFlag));
verifyLessThan(testCase, ...
    max(abs(result.predictedCfo((cfg.bootstrapPilotCount + 1):end) - ...
    trueCfo((cfg.bootstrapPilotCount + 1):end))), 0.03);

end

function testTheoreticalBerMonotonic(testCase)
ber = theoreticalLoRaBerAwgn(7, [-16; -12; -8]);
verifyGreaterThan(testCase, ber(1), ber(2));
verifyGreaterThan(testCase, ber(2), ber(3));
verifyGreaterThanOrEqual(testCase, ber, zeros(size(ber)));

end

function testSf11PhysicalDopplerBoundary(testCase)
sf = 11;
bandwidthHz = 250e3;
numSymbols = 30;
[cfoBins, dopplerHz, symbolTime, rateProfile] = ...
    buildDopplerCfoTrajectory(numSymbols, sf, bandwidthHz, 0, 500);

verifyEqual(testCase, 2 ^ sf / bandwidthHz, 0.008192, ...
    "AbsTol", 1e-12);
verifyEqual(testCase, bandwidthHz / (2 ^ sf), 122.0703125, ...
    "AbsTol", 1e-10);
verifyEqual(testCase, find(cfoBins >= 0.5, 1, "first"), 16);
verifyEqual(testCase, cfoBins(16), 0.50331648, "AbsTol", 1e-10);
verifyEqual(testCase, dopplerHz, 500 * symbolTime, "AbsTol", 1e-10);
verifyEqual(testCase, rateProfile, 500 * ones(numSymbols, 1));

end

function testVariableDopplerRateIntegration(testCase)
sf = 11;
bandwidthHz = 250e3;
rateProfile = [300; 400; 600; 500];
[~, dopplerHz, symbolTime] = buildDopplerCfoTrajectory( ...
    numel(rateProfile), sf, bandwidthHz, 12, rateProfile);
expectedHz = 12 + cumtrapz(symbolTime, rateProfile);

verifyEqual(testCase, dopplerHz, expectedHz, "AbsTol", 1e-12);

end

function testQuadraticPredictorNoiseFree(testCase)
cfg.sf = 7;
cfg.bootstrapPilotCount = 5;
cfg.historyLength = 8;
cfg.predictorOrder = 2;
cfg.initialSearchOffsets = (-1:0.1:1).';
cfg.residualSearchOffsets = (-0.5:0.1:0.5).';

numSymbols = 30;
symbolIndex = (0:(numSymbols - 1)).';
trueCfo = 0.1 + 0.008 * symbolIndex + 1e-4 * symbolIndex .^ 2;
trueBins = mod((1:numSymbols).' * 7, 2 ^ cfg.sf);
[~, txSymbols] = generateDopplerLoRaSymbols( ...
    trueBins, cfg.sf, trueCfo, 100);
result = predictiveDopplerCompensate(txSymbols, trueBins, cfg);

verifyEqual(testCase, result.detectedBins, trueBins);
verifyLessThan(testCase, ...
    max(abs(result.predictedCfo((cfg.bootstrapPilotCount + 1):end) - ...
    trueCfo((cfg.bootstrapPilotCount + 1):end))), 0.03);

end

function testBlockConfidenceThreshold(testCase)
confidence = [1; 2; 3; 8; 4; 2; 1];
tauBlock = mean(confidence) + std(confidence, 0);
mask = selectConfidentSymbols(confidence, tauBlock, 100, "block");

verifyEqual(testCase, find(mask), 4);

end
