function errorCount = detectZeroSymbolBatch( ...
    dopplerTemplate, channelCoefficient, estimateHz, snrDb, cfg)
%DETECTZEROSYMBOLBATCH Count errors using LoRa symbol-shift invariance.

arguments
    dopplerTemplate double
    channelCoefficient double
    estimateHz double
    snrDb (1,1) double {mustBeFinite}
    cfg (1,1) struct
end

[received, ~] = receivedDechirpedBatch( ...
    dopplerTemplate, channelCoefficient, estimateHz, snrDb, cfg);
spectrum = fft(received, [], 1);
if cfg.radio.ldro
    decisionMode = "peak_quantize";
    if isfield(cfg.radio, 'ldroDecisionMode')
        decisionMode = string(cfg.radio.ldroDecisionMode);
    end
    errorCount = countLdroErrors(spectrum, cfg, decisionMode);
else
    [~, oneBasedBin] = max(abs(spectrum).^2, [], 1);
    errorCount = nnz(oneBasedBin ~= 1);
end
end

function errorCount = countLdroErrors(spectrum, cfg, decisionMode)
powerSpectrum = abs(spectrum).^2;
switch decisionMode
    case "peak_quantize"
        [~, oneBasedBin] = max(powerSpectrum, [], 1);
        zeroBasedBin = oneBasedBin - 1;
        signedBin = zeroBasedBin;
        negative = zeroBasedBin >= cfg.radio.samplesPerSymbol/2;
        signedBin(negative) = signedBin(negative) - ...
            cfg.radio.samplesPerSymbol;
        quantizedSymbolBin = cfg.radio.dataBinSpacing*round( ...
            signedBin/cfg.radio.dataBinSpacing);
        errorCount = nnz(quantizedSymbolBin ~= 0);
    case "valid_bins_only"
        validOneBasedBins = 1:cfg.radio.dataBinSpacing: ...
            cfg.radio.samplesPerSymbol;
        [~, validBinIndex] = max( ...
            powerSpectrum(validOneBasedBins, :), [], 1);
        errorCount = nnz(validBinIndex ~= 1);
    otherwise
        error('detectZeroSymbolBatch:UnknownLdroDecisionMode', ...
            'Unknown LDRO decision mode: %s.', decisionMode);
end
end
