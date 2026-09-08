function [payloadFft, preambleFft, frontend] = ...
    dechirpLoRaSignalSequence(rxSignal, cfg, numPayloadSymbols)
%DECHIRPLORASIGNALSEQUENCE Convert a synchronized LoRa waveform to FFT rows.
%
% The frame is expected to start with cfg.preambleSymbols base upchirps.

arguments
    rxSignal (:,1) double
    cfg struct
    numPayloadSymbols (1,1) double {mustBeInteger, mustBeNonnegative}
end

if ~isfield(cfg, "preambleSymbols")
    cfg.preambleSymbols = 8;
end
if ~isfield(cfg, "frameStartSample")
    cfg.frameStartSample = 1;
end

numSamples = 2 ^ cfg.sf;
numFrameSymbols = cfg.preambleSymbols + numPayloadSymbols;
firstSample = cfg.frameStartSample;
lastSample = firstSample + numFrameSymbols * numSamples - 1;

if firstSample < 1 || mod(firstSample, 1) ~= 0
    error("SenLoRa:InvalidFrameStart", ...
        "frameStartSample must be a positive integer.");
end
if lastSample > numel(rxSignal)
    error("SenLoRa:SignalTooShort", ...
        "rxSignal does not contain the requested complete LoRa frame.");
end

frameSignal = rxSignal(firstSample:lastSample);
symbolMatrix = reshape(frameSignal, numSamples, numFrameSymbols).';
downchirp = conj(loraBaseUpchirp(cfg.sf));
dechirpedSymbols = symbolMatrix .* downchirp;
symbolFft = fft(dechirpedSymbols, [], 2) / sqrt(numSamples);

preambleRange = 1:cfg.preambleSymbols;
payloadRange = cfg.preambleSymbols + (1:numPayloadSymbols);
preambleFft = symbolFft(preambleRange, :);
payloadFft = symbolFft(payloadRange, :);

frontend = struct();
frontend.frameSignal = frameSignal;
frontend.symbolMatrix = symbolMatrix;
frontend.dechirpedSymbols = dechirpedSymbols;
frontend.symbolFft = symbolFft;
frontend.payloadFft = payloadFft;
frontend.preambleFft = preambleFft;
frontend.frameStartSample = firstSample;
frontend.samplesPerSymbol = numSamples;

end
