function result = satelliteFig3HardDecision(symbolSamples, config)
%SATELLITEFIG3HARDDECISION Dechirp and map MATLAB FFT bin to CSS labels.
%   rawFftBin is the physical FFT index and equals the waveform label for
%   this discrete up-chirp convention; grayLabel is used by the FEC/LLR path.

m = config.samplesPerSymbol;
if numel(symbolSamples) ~= m
    error('SatelliteFig3:InvalidDemodLength','Expected one full CSS symbol.');
end
n = (0:m-1).';
upChirp = exp(1i*2*pi*(n.^2/(2*m)-n/2));
spectrum = fft(symbolSamples(:).*conj(upChirp))/sqrt(m);
magnitude = abs(spectrum);
[peak,peakIndex] = max(magnitude);
sorted = sort(magnitude,'descend');
rawFftBin = peakIndex-1;
waveformBin = rawFftBin;
result = struct( ...
    'waveformBin',waveformBin, ...
    'rawFftBin',rawFftBin, ...
    'grayLabel',double(satelliteFig3GrayEncode(uint32(rawFftBin))), ...
    'peakRatio',peak/max(sorted(2),eps), ...
    'peakMetric',peak, ...
    'spectrum',spectrum);
end
