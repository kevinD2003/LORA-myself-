function estimate = strictPaperCentroids(rx,config)
%STRICTPAPERCENTROIDS Batched equivalent of the reference ten-point FFT.
% FFT columns and vectorized centroid gathers reduce memory strides. Every
% sample, window coefficient, peak and centroid weight is unchanged.
m=config.samplesPerSymbol;
if size(rx,2)~=m || config.zeroPaddingFactor~=4
    error('StrictPaper:CentroidShape','Expected complete symbols and 4x padding.');
end
persistent cachedM down window
if isempty(cachedM) || cachedM~=m
    n=0:m-1;
    down=conj(exp(1i*2*pi*(n.^2/(2*m)-n/2)));
    window=0.5-0.5*cos(2*pi*n/m);
    cachedM=m;
end
fftLength=4*m;
spectrum=abs(fft((rx.*down.*window).',fftLength,1));
[~,peaks]=max(spectrum,[],1);
offsets=(-4:5).';
unwrapped=peaks-1+offsets;
columns=(0:size(rx,1)-1)*fftLength;
weights=spectrum(mod(unwrapped,fftLength)+1+columns);
centroid=sum(unwrapped.*weights,1)./max(sum(weights,1),eps);
estimate=struct('rawBins',mod(centroid.'/4,m), ...
    'peakBins',mod((peaks.'-1)/4,m),'centroidSampleCount',10, ...
    'offsets',offsets.');
end
