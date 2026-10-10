function estimate = dreEstimatePaperCentroids10(rx,config)
%DREESTIMATEPAPERCENTROIDS10 Hann, 4x FFT, ten-sample peak centroid.
%   The paper says "centroid size of 10" without specifying how an even
%   window is centered. Use four samples below and five above the peak,
%   including the peak itself: exactly ten contiguous FFT samples.

m = config.samplesPerSymbol;
if size(rx,2) ~= m || config.zeroPaddingFactor ~= 4
    error('DRE:PaperCentroidShape','Expected complete symbols and 4x padding.');
end
n = 0:m-1;
downchirp = conj(exp(1i*2*pi*(n.^2/(2*m)-n/2)));
window = 0.5-0.5*cos(2*pi*n/m);
fftLength = 4*m;
spectrum = abs(fft(rx.*downchirp.*window,fftLength,2));
[~,peakOneBased] = max(spectrum,[],2);
offsets = -4:5;
centroid = zeros(size(rx,1),1);
for row=1:size(rx,1)
    peak = peakOneBased(row)-1;
    unwrapped = peak+offsets;
    weights = spectrum(row,mod(unwrapped,fftLength)+1);
    centroid(row) = sum(unwrapped.*weights)/max(sum(weights),eps);
end
estimate = struct('rawBins',mod(centroid/4,m), ...
    'peakBins',mod((peakOneBased-1)/4,m), ...
    'centroidSampleCount',10,'offsets',offsets);
end
