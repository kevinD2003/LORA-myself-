function [rxSignal, metadata] = synthesizeLoRaSignalSequence( ...
    symbolBins, cfg, symbolSnrDb, interferenceBins, interferenceSnrDb)
%SYNTHESIZELORASIGNALSEQUENCE Generate a preamble and LoRa payload waveform.
%
% SNR values are defined at the dechirped FFT output. interferenceBins uses
% NaN for symbols without a competing LoRa chirp.

arguments
    symbolBins (:,1) double {mustBeInteger, mustBeNonnegative}
    cfg struct
    symbolSnrDb (:,1) double
    interferenceBins (:,1) double = zeros(0, 1)
    interferenceSnrDb (:,1) double = zeros(0, 1)
end

sf = cfg.sf;
numSamples = 2 ^ sf;
numPayloadSymbols = numel(symbolBins);

if any(symbolBins >= numSamples)
    error("SenLoRa:InvalidSymbolBin", ...
        "symbolBins must be in [0, 2^SF - 1].");
end
if numel(symbolSnrDb) ~= numPayloadSymbols
    error("SenLoRa:InvalidSnrLength", ...
        "symbolSnrDb must have one value per payload symbol.");
end

if ~isfield(cfg, "preambleSymbols")
    cfg.preambleSymbols = 8;
end
if ~isfield(cfg, "preambleSnrDb")
    cfg.preambleSnrDb = 20;
end

if isempty(interferenceBins)
    interferenceBins = nan(numPayloadSymbols, 1);
end
if isempty(interferenceSnrDb)
    interferenceSnrDb = -inf(numPayloadSymbols, 1);
end
if numel(interferenceBins) ~= numPayloadSymbols || ...
        numel(interferenceSnrDb) ~= numPayloadSymbols
    error("SenLoRa:InvalidInterferenceLength", ...
        "Interference inputs must have one value per payload symbol.");
end

validInterference = ~isnan(interferenceBins);
if any(interferenceBins(validInterference) < 0) || ...
        any(interferenceBins(validInterference) >= numSamples) || ...
        any(mod(interferenceBins(validInterference), 1) ~= 0)
    error("SenLoRa:InvalidInterferenceBin", ...
        "Finite interference bins must be integers in [0, 2^SF - 1].");
end

numSymbols = cfg.preambleSymbols + numPayloadSymbols;
txSignal = complex(zeros(numSymbols * numSamples, 1));
baseUpchirp = loraBaseUpchirp(sf).';

preambleAmplitude = sqrt(10 ^ (cfg.preambleSnrDb / 10) / numSamples);
for idx = 1:cfg.preambleSymbols
    sampleRange = (idx - 1) * numSamples + (1:numSamples);
    txSignal(sampleRange) = preambleAmplitude * baseUpchirp;
end

for idx = 1:numPayloadSymbols
    frameSymbolIdx = cfg.preambleSymbols + idx;
    sampleRange = (frameSymbolIdx - 1) * numSamples + (1:numSamples);
    signalAmplitude = sqrt(10 ^ (symbolSnrDb(idx) / 10) / numSamples);
    txSignal(sampleRange) = signalAmplitude * ...
        modulateLoRaSymbol(symbolBins(idx), sf).';

    if validInterference(idx)
        interferenceAmplitude = sqrt( ...
            10 ^ (interferenceSnrDb(idx) / 10) / numSamples);
        txSignal(sampleRange) = txSignal(sampleRange) + ...
            interferenceAmplitude * ...
            modulateLoRaSymbol(interferenceBins(idx), sf).';
    end
end

noise = (randn(size(txSignal)) + 1i * randn(size(txSignal))) / sqrt(2);
rxSignal = txSignal + noise;

metadata = struct();
metadata.txSignal = txSignal;
metadata.symbolBins = symbolBins;
metadata.symbolSnrDb = symbolSnrDb;
metadata.interferenceBins = interferenceBins;
metadata.interferenceSnrDb = interferenceSnrDb;
metadata.preambleSymbols = cfg.preambleSymbols;
metadata.samplesPerSymbol = numSamples;

end
