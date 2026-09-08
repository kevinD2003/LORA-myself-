function result = senloraDynamicConfidenceIteration( ...
        rxSymbols, config, knownPilotBins, options)
%SENLORADYNAMICCONFIDENCEITERATION Run causal-style SenLoRa mask iterations.
%
% The function accepts only the received symbol waveforms, four known
% bootstrap bins, and optional previous confidence state.  Payload truth is
% deliberately absent from this interface.  A previous iteration's
% confidence mask is used to ask the virtual-pilot tracker for a new
% compensation pass; FFT/Gray-LLR/soft-Hamming confidence then produces the
% next mask.

arguments
    rxSymbols (:,:) double
    config (1,1) struct
    knownPilotBins (:,1) double
    options.PreviousMask (:,1) logical = false(0,1)
    options.MaxIterations (1,1) double = NaN
end

numSymbols = size(rxSymbols,1);
bootstrapCount = numel(knownPilotBins);
if isempty(options.MaxIterations) || ~isfinite(options.MaxIterations)
    maxIterations = config.maxSenLoRaIterations;
else
    maxIterations = max(1, floor(options.MaxIterations));
end
if isempty(options.PreviousMask)
    currentMask = false(numSymbols,1);
    currentMask(1:bootstrapCount) = true;
else
    currentMask = options.PreviousMask;
    if numel(currentMask) ~= numSymbols
        error("SenLoRa:InvalidPreviousMask", ...
            "PreviousMask must contain one value per frame symbol.");
    end
    currentMask(1:bootstrapCount) = true;
end

confidenceInput = nan(numSymbols,1);
iterationHistory = repmat(struct(), 0, 1);
previousGlobal = NaN;
converged = false;
decisionPeakRatioThreshold = config.decisionPeakRatioThreshold;
estimatedSampleSnrDb = NaN;

for iterationIdx = 1:maxIterations
    tracker = trackSenLoRaVirtualPilots( ...
        rxSymbols, config, knownPilotBins, currentMask, ...
        PilotConfidence=confidenceInput, ...
        PeakRatioThreshold=config.peakRatioThreshold, ...
        DecisionPeakRatioThreshold=decisionPeakRatioThreshold, ...
        HuberThresholdBins=config.huberThresholdBins, ...
        HistoryDecay=config.historyDecay);

    compensatedFft = dechirpFftRows(tracker.compensatedSymbols, config.sf);
    if bootstrapCount >= 2
        preambleFft = compensatedFft(1:bootstrapCount,:);
    else
        preambleFft = compensatedFft(1,:);
    end
    estimatedSampleSnrDb = estimateSampleSnrDb(preambleFft,config.sf);
    thresholdScale = config.confidenceThresholdScale;
    decisionPeakRatioThreshold = config.decisionPeakRatioThreshold;
    if config.adaptiveConfidenceEnabled && ...
            estimatedSampleSnrDb >= config.adaptiveConfidenceSwitchSnrDb
        thresholdScale = config.highSnrConfidenceThresholdScale;
        decisionPeakRatioThreshold = ...
            config.highSnrDecisionPeakRatioThreshold;
    end
    confidencePass = senloraConfidenceBlocks( ...
        compensatedFft, preambleFft, config, previousGlobal,thresholdScale);
    previousGlobal = confidencePass.finalTauGlobal;

    nextMask = confidencePass.confidentMask;
    nextMask(~confidencePass.confidenceReadyFlag) = false;
    nextMask(1:bootstrapCount) = true;

    iterationHistory(iterationIdx).iteration = iterationIdx;
    iterationHistory(iterationIdx).requestedMask = currentMask;
    iterationHistory(iterationIdx).confidenceReadyFlag = ...
        confidencePass.confidenceReadyFlag;
    iterationHistory(iterationIdx).confidenceMask = ...
        confidencePass.confidentMask;
    iterationHistory(iterationIdx).nextMask = nextMask;
    iterationHistory(iterationIdx).confidence = confidencePass.confidence;
    iterationHistory(iterationIdx).tauBlock = confidencePass.tauBlock;
    iterationHistory(iterationIdx).tauGlobal = confidencePass.tauGlobal;
    iterationHistory(iterationIdx).estimatedSampleSnrDb = estimatedSampleSnrDb;
    iterationHistory(iterationIdx).thresholdScale = thresholdScale;
    iterationHistory(iterationIdx).decisionPeakRatioThreshold = ...
        decisionPeakRatioThreshold;
    iterationHistory(iterationIdx).tracker = tracker;
    iterationHistory(iterationIdx).confidencePass = confidencePass;
    iterationHistory(iterationIdx).acceptedPilotCount = ...
        sum(tracker.pilotUpdateFlag);

    if isequal(nextMask, currentMask)
        converged = true;
        currentMask = nextMask;
        break
    end
    currentMask = nextMask;
    confidenceInput = confidencePass.confidence;
end

iterationHistory = iterationHistory(1:numel(iterationHistory));
result = struct( ...
    "detectedBins", tracker.detectedBins, ...
    "compensatedSymbols", tracker.compensatedSymbols, ...
    "confidence", confidencePass.confidence, ...
    "confidenceReadyFlag", confidencePass.confidenceReadyFlag, ...
    "confidentMask", confidencePass.confidentMask, ...
    "tauBlock", confidencePass.tauBlock, ...
    "tauGlobal", confidencePass.tauGlobal, ...
    "finalTauGlobal", confidencePass.finalTauGlobal, ...
    "estimatedSampleSnrDb", estimatedSampleSnrDb, ...
    "pilotUpdateRequested", tracker.pilotUpdateRequested, ...
    "pilotUpdateFlag", tracker.pilotUpdateFlag, ...
    "pilotCount", tracker.pilotCount, ...
    "residualPeakRatio", tracker.residualPeakRatio, ...
    "measuredResidualBins", tracker.measuredResidualBins, ...
    "measuredResidualPhaseRad", tracker.measuredResidualPhaseRad, ...
    "predictedCfoBins", tracker.predictedCfoBins, ...
    "predictedRateBinsPerSec", tracker.predictedRateBinsPerSec, ...
    "predictedRateHzPerSec", tracker.predictedRateHzPerSec, ...
    "measuredCfoBins", tracker.measuredCfoBins, ...
    "iterationHistory", iterationHistory, ...
    "iterations", numel(iterationHistory), ...
    "converged", converged, ...
    "finalMask", currentMask);
end

function fftRows = dechirpFftRows(symbolRows, sf)
numSamples = 2^sf;
sampleIndex = (0:numSamples-1).';
baseUpchirp = exp(1i*2*pi*(sampleIndex.^2/(2*numSamples)-sampleIndex/2));
dechirped = symbolRows .* conj(baseUpchirp.');
fftRows = fft(dechirped, [], 2)/sqrt(numSamples);
end

function pass = senloraConfidenceBlocks( ...
        fftRows, preambleFft, config, previousTauGlobal,thresholdScale)
numSymbols = size(fftRows,1);
blockSize = 4 + config.cr;
numBins = 2^config.sf;
if size(fftRows,2) ~= numBins
    error("SenLoRa:InvalidConfidenceFft", ...
        "FFT rows must contain 2^SF bins.");
end

confidence = nan(numSymbols,1);
tauBlock = nan(numSymbols,1);
tauGlobal = nan(numSymbols,1);
ready = false(numSymbols,1);
confident = false(numSymbols,1);
hardBins = zeros(numSymbols,1);
llrEnergy = nan(numSymbols,1);
blockTau = previousTauGlobal;
if ~isfinite(blockTau)
    blockTau = NaN;
end

for symbolIdx = 1:numSymbols
    [~, hardIndex] = max(abs(fftRows(symbolIdx,:)));
    hardBins(symbolIdx) = hardIndex-1;
end

payloadStart = config.bootstrapPilotCount+1;
payloadSymbolCount = max(0,numSymbols-config.bootstrapPilotCount);
blockCount = floor(payloadSymbolCount/blockSize);
for blockIdx = 1:blockCount
    rows = payloadStart-1+(blockIdx-1)*blockSize+(1:blockSize);
    blockFft = fftRows(rows,:);
    noisePower = localNoisePower(preambleFft);
    grayBits = localGrayBits(config.sf);
    llrSymbols = zeros(blockSize,config.sf);
    for rowIdx = 1:blockSize
        logProb = localBinLogProb(blockFft(rowIdx,:), noisePower, ...
            config.probMode);
        llrSymbols(rowIdx,:) = localBinLogProbToLlr(logProb,grayBits);
    end
    llrCodewords = llrSymbols.';
    [decodedBits, ~, scores] = ...
        localSoftHammingDecodeBlock(llrCodewords, config.cr);
    llrPrime = localAmendLlr(llrCodewords, decodedBits, scores, ...
        config.amendMode);
    llrPrimeSymbols = llrPrime.';
    confidenceBlock = sum(abs(llrPrimeSymbols).^2,2);
    tauLocal = mean(confidenceBlock) + std(confidenceBlock,0);
    if ~isfinite(blockTau)
        blockTau = tauLocal;
    else
        blockTau = config.confidenceAlpha*blockTau + ...
            (1-config.confidenceAlpha)*tauLocal;
    end
    confidence(rows) = confidenceBlock;
    llrEnergy(rows) = confidenceBlock;
    tauBlock(rows) = tauLocal;
    tauGlobal(rows) = blockTau;
    ready(rows) = true;
    confident(rows) = confidenceBlock >= thresholdScale*blockTau;
end

pass = struct( ...
    "confidence", confidence, ...
    "tauBlock", tauBlock, ...
    "tauGlobal", tauGlobal, ...
    "confidentMask", confident, ...
    "confidenceReadyFlag", ready, ...
    "hardBins", hardBins, ...
    "llrEnergy", llrEnergy, ...
    "finalTauGlobal", blockTau, ...
    "completedBlockCount", blockCount);
end

function sampleSnrDb = estimateSampleSnrDb(preambleFft,sf)
meanPower = mean(abs(preambleFft).^2,1);
noisePower = max(mean(meanPower(2:end)),eps);
signalToNoiseFft = max(max(meanPower)/noisePower-1,eps);
sampleSnrDb = 10*log10(signalToNoiseFft/(2^sf));
end

function noisePower = localNoisePower(preambleFft)
powerSpectrum = abs(preambleFft).^2;
if size(powerSpectrum,1) > 1
    powerSpectrum = mean(powerSpectrum,1);
end
noisePower = max(mean(powerSpectrum(2:end)),eps);
end

function logProb = localBinLogProb(chirpFft, noisePower, mode)
energy = abs(chirpFft).^2;
switch string(mode)
    case "paper"
        logits = energy-noisePower;
    case "noise-scaled"
        logits = (energy-noisePower)/max(noisePower,eps);
    otherwise
        error("SenLoRa:UnknownProbabilityMode", ...
            "Unsupported SenLoRa probability mode.");
end
maxLogit = max(logits);
logProb = logits-(maxLogit+log(sum(exp(logits-maxLogit))));
end

function grayBits = localGrayBits(sf)
numBins = 2^sf;
grayBits = false(numBins,sf);
for bin = 0:numBins-1
    shifted = mod(bin-1,numBins);
    grayValue = bitxor(shifted,floor(shifted/2));
    grayBits(bin+1,:) = dec2bin(grayValue,sf) == '1';
end
end

function llr = localBinLogProbToLlr(logProb, grayBits)
llr = zeros(1,size(grayBits,2));
for bitIdx = 1:size(grayBits,2)
    oneMask = grayBits(:,bitIdx).';
    llr(bitIdx) = localLogSumExp(logProb(oneMask))- ...
        localLogSumExp(logProb(~oneMask));
end
end

function value = localLogSumExp(x)
maxValue = max(x);
value = maxValue+log(sum(exp(x-maxValue)));
end

function [decodedBits, decodedNibbles, scores] = ...
        localSoftHammingDecodeBlock(llrCodewords, cr)
sf = size(llrCodewords,1);
codeLength = 4+cr;
decodedBits = false(sf,codeLength);
decodedNibbles = zeros(sf,1);
scores = zeros(sf,1);
for idx = 1:sf
    [decodedBits(idx,:),decodedNibbles(idx),scores(idx)] = ...
        localSoftHammingDecodeOne(llrCodewords(idx,:),cr);
end
end

function [bestBits,bestNibble,bestScore] = ...
        localSoftHammingDecodeOne(llr,cr)
codeLength = 4+cr;
codeTable = localHammingCodeTable(cr);
hardBits = llr>0;
candidateScores = zeros(numel(codeTable),1);
candidateBits = false(numel(codeTable),codeLength);
for idx = 1:numel(codeTable)
    bits = localCodewordBits(codeTable(idx),cr);
    sameMask = bits==hardBits;
    candidateScores(idx) = sum(abs(llr(sameMask)).^2)- ...
        sum(abs(llr(~sameMask)).^2);
    candidateBits(idx,:) = bits;
end
[bestScore,bestIdx] = max(candidateScores);
bestBits = candidateBits(bestIdx,:);
bestNibble = bestIdx-1;
end

function codeTable = localHammingCodeTable(cr)
if cr == 1
    codeTable = [0,24,40,48,72,80,96,120,136,144,160,184,192,216,232,240];
else
    codeTable = [0,23,45,58,78,89,99,116,139,156,166,177,197,210,232,255];
end
end

function bits = localCodewordBits(codeValue,cr)
bits = dec2bin(codeValue,8);
bits = bits(1:(4+cr)) == '1';
end

function llrPrime = localAmendLlr(llr,decodedBits,scores,mode)
switch string(mode)
    case "identity"
        llrPrime = llr;
    case "decoded-sign"
        llrPrime = llr;
        codeLength = size(llr,2);
        for row = 1:size(llr,1)
            signBits = 2*double(decodedBits(row,:))-1;
            reliability = sqrt(max(scores(row),0)/codeLength);
            target = signBits.*max(abs(llr(row,:)),reliability);
            llrPrime(row,:) = 0.5*llr(row,:)+0.5*target;
        end
    otherwise
        error("SenLoRa:UnknownAmendMode", ...
            "Unsupported amend mode.");
end
end
