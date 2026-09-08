function estimateHz = estimateFromDownchirp(receivedDownchirps, cfg)
%ESTIMATEFROMDOWNCHIRP Point estimate from synchronization downchirps.
% The paper multiplies each received downchirp by a pure upchirp before the
% FFT (Eq. 10). Columns correspond to independent packets.

arguments
    receivedDownchirps double
    cfg (1,1) struct
end

numSamples = cfg.radio.samplesPerSymbol;
validateattributes(receivedDownchirps, {'numeric'}, {'nrows', numSamples});
dechirped = receivedDownchirps.*loraPureUpchirp( ...
    cfg.radio.spreadingFactor);
estimateHz = estimateFftFrequency( ...
    dechirped, cfg.radio.sampleRateHz, ...
    numSamples*cfg.receiver.estimatorFftPaddingFactor);
end
