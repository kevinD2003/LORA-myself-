function estimate = dreEstimateCentroids(rx,config)
%DREESTIMATECENTROIDS Hann, zero-padded FFT, and circular peak centroid.

if size(rx,2) ~= config.samplesPerSymbol
    error('DRE:SymbolShape','Each row must contain one complete LoRa symbol.');
end
m = config.samplesPerSymbol;
n = 0:m-1;
downchirp = conj(exp(1i*2*pi*(n.^2/(2*m)-n/2)));
window = 0.5-0.5*cos(2*pi*n/m);
dechirped = rx.*downchirp.*window;
fftLength = config.zeroPaddingFactor*m;
spectrum = abs(fft(dechirped,fftLength,2));
[~,peakOneBased] = max(spectrum,[],2);
count = config.centroidSampleCount;
offsets = -count:count;
centroid = zeros(size(rx,1),1);
for row = 1:size(rx,1)
    peakZero = peakOneBased(row)-1;
    unwrappedIndex = peakZero+offsets;
    wrappedIndex = mod(unwrappedIndex,fftLength)+1;
    weights = spectrum(row,wrappedIndex);
    centroid(row) = sum(unwrappedIndex.*weights)/max(sum(weights),eps);
end
rawBins = mod(centroid/config.zeroPaddingFactor,m);
estimate = struct('rawBins',rawBins,'peakBins', ...
    mod((peakOneBased-1)/config.zeroPaddingFactor,m), ...
    'zeroPaddingFactor',config.zeroPaddingFactor, ...
    'centroidNeighborRadius',count);
end
