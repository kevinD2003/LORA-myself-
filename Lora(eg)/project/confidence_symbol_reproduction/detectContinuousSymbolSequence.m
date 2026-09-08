function result = detectContinuousSymbolSequence( ...
    payloadFft, preambleFft, cfg, referenceBins)
%DETECTCONTINUOUSSYMBOLSEQUENCE Detect flags over a continuous symbol stream.
%
% receiverDecisionFlag meanings:
%   +1: selected by the paper's confidence threshold (likely correct)
%   -1: rejected by the confidence threshold (unsafe/possibly incorrect)
%    0: pending because the final interleaving block is incomplete
%
% truthFlag meanings when referenceBins are supplied:
%   +1: hard FFT-bin decision is correct
%   -1: hard FFT-bin decision is incorrect

arguments
    payloadFft (:,:) double
    preambleFft (:,:) double
    cfg struct
    referenceBins (:,1) double = zeros(0, 1)
end

numSymbols = size(payloadFft, 1);
numBins = 2 ^ cfg.sf;
blockSize = 4 + cfg.cr;

if size(payloadFft, 2) ~= numBins
    error("SenLoRa:InvalidBinCount", ...
        "payloadFft must have 2^SF columns.");
end

hasReference = ~isempty(referenceBins);
if hasReference && numel(referenceBins) ~= numSymbols
    error("SenLoRa:ReferenceLengthMismatch", ...
        "referenceBins must have one entry per payload symbol.");
end
if hasReference && (any(referenceBins < 0) || ...
        any(referenceBins >= numBins) || any(mod(referenceBins, 1) ~= 0))
    error("SenLoRa:InvalidReferenceBin", ...
        "referenceBins must be integers in [0, 2^SF - 1].");
end

symbolIndex = (1:numSymbols).';
blockIndex = ceil(symbolIndex / blockSize);
detectedBins = zeros(numSymbols, 1);
correctFlag = false(numSymbols, 1);
errorFlag = false(numSymbols, 1);
confidenceReadyFlag = false(numSymbols, 1);
confidentFlag = false(numSymbols, 1);
confidence = nan(numSymbols, 1);
tauBlock = nan(numSymbols, 1);
tauGlobal = nan(numSymbols, 1);
falseAcceptFlag = false(numSymbols, 1);
acceptedCorrectFlag = false(numSymbols, 1);
receiverDecisionFlag = zeros(numSymbols, 1, "int8");
truthFlag = zeros(numSymbols, 1, "int8");

state = struct();
blockResults = cell(0, 1);

for idx = 1:numSymbols
    if hasReference
        referenceBin = referenceBins(idx);
    else
        referenceBin = [];
    end

    [event, state] = stepSenLoRaSymbolDetector( ...
        payloadFft(idx, :), preambleFft, cfg, state, referenceBin);
    detectedBins(idx) = event.detectedBin;
    correctFlag(idx) = event.correctArrivalFlag;
    errorFlag(idx) = event.errorArrivalFlag;

    if event.blockReadyFlag
        block = event.block;
        blockIdx = block.symbolIndex;
        confidenceReadyFlag(blockIdx) = true;
        confidentFlag(blockIdx) = block.confidentFlag;
        confidence(blockIdx) = block.confidence;
        tauBlock(blockIdx) = block.tauBlock;
        tauGlobal(blockIdx) = block.tauGlobal;
        falseAcceptFlag(blockIdx) = block.falseAcceptFlag;
        acceptedCorrectFlag(blockIdx) = block.acceptedCorrectFlag;
        receiverDecisionFlag(blockIdx) = block.receiverDecisionFlag;
        blockResults{end + 1, 1} = block.detectorResult; %#ok<AGROW>
    end
end

if hasReference
    truthFlag(correctFlag) = 1;
    truthFlag(errorFlag) = -1;
end

result = struct();
result.symbolIndex = symbolIndex;
result.blockIndex = blockIndex;
result.referenceBins = referenceBins;
result.detectedBins = detectedBins;
result.correctFlag = correctFlag;
result.errorFlag = errorFlag;
result.truthFlag = truthFlag;
result.confidenceReadyFlag = confidenceReadyFlag;
result.confidentFlag = confidentFlag;
result.lowConfidenceFlag = confidenceReadyFlag & ~confidentFlag;
result.receiverDecisionFlag = receiverDecisionFlag;
result.confidence = confidence;
result.tauBlock = tauBlock;
result.tauGlobal = tauGlobal;
result.acceptedCorrectFlag = acceptedCorrectFlag;
result.falseAcceptFlag = falseAcceptFlag;
result.numCompletedBlocks = state.completedBlocks;
result.numPendingSymbols = size(state.fftBuffer, 1);
result.finalState = state;
result.blockResults = blockResults;

end
