function report = validateLoraNoiseless(cfg, symbolCount)
%VALIDATELORANOISELESS Verify random LoRa symbols with no noise or Doppler.

arguments
    cfg (1,1) struct
    symbolCount (1,1) double {mustBeInteger, mustBePositive}
end

validateattributes(symbolCount, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});
previousRandomState = rng;
restoreRandomState = onCleanup(@() rng(previousRandomState));
rng(cfg.monteCarlo.randomSeed, 'twister');
numSamples = cfg.radio.samplesPerSymbol;
batchSize = 64;
processed = 0;
symbolErrors = 0;
sampleIndex = (0:numSamples-1).';
upchirp = loraPureUpchirp(cfg.radio.spreadingFactor);
downchirp = conj(upchirp);
while processed < symbolCount
    currentBatch = min(batchSize, symbolCount-processed);
    symbols = randi([0, numSamples-1], 1, currentBatch);
    tones = exp(1j*2*pi*sampleIndex*symbols/numSamples);
    received = upchirp.*tones;
    spectrum = fft(received.*downchirp, [], 1);
    [~, detectedBin] = max(abs(spectrum).^2, [], 1);
    symbolErrors = symbolErrors + nnz(detectedBin-1 ~= symbols);
    processed = processed + currentBatch;
end
report.symbolCount = symbolCount;
report.symbolErrors = symbolErrors;
report.ser = symbolErrors/symbolCount;
report.passed = symbolErrors == 0;
end
