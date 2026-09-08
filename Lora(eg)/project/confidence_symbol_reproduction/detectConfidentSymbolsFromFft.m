function result = detectConfidentSymbolsFromFft(payloadFft, preambleFft, cfg, state)
%DETECTCONFIDENTSYMBOLSFROMFFT Detect SenLoRa confident symbols from FFTs.
%
% payloadFft is (4 + CR)-by-2^SF. Each row is one dechirped payload
% chirp after FFT. preambleFft is either P-by-2^SF or 1-by-2^SF.

arguments
    payloadFft (:,:) double
    preambleFft (:,:) double
    cfg struct
    state = []
end

sf = cfg.sf;
cr = cfg.cr;
numSymbols = cr + 4;
numBins = 2 ^ sf;

if size(payloadFft, 1) ~= numSymbols
    error("SenLoRa:InvalidPayloadSize", ...
        "payloadFft must have 4 + CR rows.");
end

if size(payloadFft, 2) ~= numBins
    error("SenLoRa:InvalidBinCount", ...
        "payloadFft must have 2^SF columns.");
end

if ~isfield(cfg, "probMode")
    cfg.probMode = "paper";
end

if ~isfield(cfg, "amendMode")
    cfg.amendMode = "identity";
end

if ~isfield(cfg, "alpha")
    cfg.alpha = 0.8;
end

if ~isfield(cfg, "thresholdMode")
    cfg.thresholdMode = "global";
end

noisePower = estimateNoisePower(preambleFft);
grayBits = loraGrayBits(sf);
llrSymbols = zeros(numSymbols, sf);

for symbolIdx = 1:numSymbols
    logProb = fftToBinLogProb(payloadFft(symbolIdx, :), noisePower, cfg.probMode);
    llrSymbols(symbolIdx, :) = binLogProbToLlr(logProb, grayBits);
end

% This minimal reproduction uses the same block transpose model as the
% synthetic demo. Replace this function with an exact LoRa diagonal
% deinterleaver when feeding raw PHY payload blocks.
llrCodewords = deinterleaveBlock(llrSymbols);
[decodedBits, decodedNibbles, codewordScores] = softHammingDecodeBlock( ...
    llrCodewords, cr);
llrPrime = amendLlr(llrCodewords, decodedBits, codewordScores, cfg.amendMode);
llrPrimeSymbols = interleaveBlockBack(llrPrime);

confidence = symbolConfidence(llrPrimeSymbols);
[tauBlock, tauGlobal] = updateConfidenceThreshold(confidence, cfg.alpha, state);
confidentMask = selectConfidentSymbols(confidence, tauBlock, tauGlobal, cfg.thresholdMode);

result = struct();
result.noisePower = noisePower;
result.llrSymbols = llrSymbols;
result.llrCodewords = llrCodewords;
result.decodedBits = decodedBits;
result.decodedNibbles = decodedNibbles;
result.codewordScores = codewordScores;
result.llrPrime = llrPrime;
result.confidence = confidence;
result.tauBlock = tauBlock;
result.tauGlobal = tauGlobal;
result.confidentMask = confidentMask;
result.confidentIdx = find(confidentMask);
result.state = struct("tauGlobal", tauGlobal);

end

