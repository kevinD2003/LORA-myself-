function [event, state] = stepSenLoRaSymbolDetector( ...
    symbolFft, preambleFft, cfg, state, referenceBin)
%STEPSENLORASYMBOLDETECTOR Process one symbol in a continuous FFT stream.
%
% A hard FFT-bin decision is available immediately. SenLoRa confidence is
% emitted after 4 + CR symbols have filled one interleaving block.

arguments
    symbolFft (1,:) double
    preambleFft (:,:) double
    cfg struct
    state struct = struct()
    referenceBin = []
end

sf = cfg.sf;
cr = cfg.cr;
numBins = 2 ^ sf;
blockSize = 4 + cr;

if numel(symbolFft) ~= numBins
    error("SenLoRa:InvalidBinCount", ...
        "symbolFft must contain 2^SF FFT bins.");
end

if ~isempty(referenceBin)
    validateattributes(referenceBin, {'numeric'}, ...
        {'scalar', 'integer', '>=', 0, '<', numBins});
end

if isempty(fieldnames(state))
    state.fftBuffer = complex(zeros(0, numBins));
    state.referenceBuffer = zeros(0, 1);
    state.symbolIndexBuffer = zeros(0, 1);
    state.thresholdState = [];
    state.totalSymbols = 0;
    state.completedBlocks = 0;
end

requiredFields = ["fftBuffer", "referenceBuffer", "symbolIndexBuffer", ...
    "thresholdState", "totalSymbols", "completedBlocks"];
for fieldName = requiredFields
    if ~isfield(state, fieldName)
        error("SenLoRa:InvalidStreamState", ...
            "Stream state is missing field %s.", fieldName);
    end
end

state.totalSymbols = state.totalSymbols + 1;
state.fftBuffer(end + 1, :) = symbolFft;
state.symbolIndexBuffer(end + 1, 1) = state.totalSymbols;
if isempty(referenceBin)
    state.referenceBuffer(end + 1, 1) = NaN;
else
    state.referenceBuffer(end + 1, 1) = referenceBin;
end

[~, hardIdx] = max(abs(symbolFft));
detectedBin = hardIdx - 1;
hasReference = ~isempty(referenceBin);

event = struct();
event.symbolIndex = state.totalSymbols;
event.detectedBin = detectedBin;
event.hasReferenceFlag = hasReference;
event.correctArrivalFlag = hasReference && detectedBin == referenceBin;
event.errorArrivalFlag = hasReference && detectedBin ~= referenceBin;
event.blockReadyFlag = false;
event.block = [];

if size(state.fftBuffer, 1) < blockSize
    return;
end

blockResult = detectConfidentSymbolsFromFft( ...
    state.fftBuffer, preambleFft, cfg, state.thresholdState);
state.thresholdState = blockResult.state;
state.completedBlocks = state.completedBlocks + 1;

[~, hardIndices] = max(abs(state.fftBuffer), [], 2);
blockDetectedBins = hardIndices - 1;
hasBlockReference = ~isnan(state.referenceBuffer);
correctFlag = hasBlockReference & ...
    blockDetectedBins == state.referenceBuffer;
errorFlag = hasBlockReference & ...
    blockDetectedBins ~= state.referenceBuffer;

block = struct();
block.blockIndex = state.completedBlocks;
block.symbolIndex = state.symbolIndexBuffer;
block.referenceBins = state.referenceBuffer;
block.detectedBins = blockDetectedBins;
block.hasReferenceFlag = hasBlockReference;
block.correctFlag = correctFlag;
block.errorFlag = errorFlag;
block.confidentFlag = blockResult.confidentMask;
block.lowConfidenceFlag = ~blockResult.confidentMask;
block.receiverDecisionFlag = int8(2 * blockResult.confidentMask - 1);
block.confidence = blockResult.confidence;
block.tauBlock = repmat(blockResult.tauBlock, blockSize, 1);
block.tauGlobal = repmat(blockResult.tauGlobal, blockSize, 1);
block.falseAcceptFlag = blockResult.confidentMask & errorFlag;
block.acceptedCorrectFlag = blockResult.confidentMask & correctFlag;
block.detectorResult = blockResult;

event.blockReadyFlag = true;
event.block = block;

state.fftBuffer = complex(zeros(0, numBins));
state.referenceBuffer = zeros(0, 1);
state.symbolIndexBuffer = zeros(0, 1);

end
