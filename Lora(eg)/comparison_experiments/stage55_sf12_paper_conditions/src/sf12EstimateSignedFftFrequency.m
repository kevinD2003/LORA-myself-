function frequencyHz = sf12EstimateSignedFftFrequency(samples,fs,fftLength)
%SF12ESTIMATESIGNEDFFTFREQUENCY Native signed FFT peak estimator.

if nargin < 3
    fftLength = numel(samples);
end
spectrum = fft(samples(:),fftLength);
[~,bin] = max(abs(spectrum).^2);
signedBin = bin-1;
if signedBin >= fftLength/2
    signedBin = signedBin-fftLength;
end
frequencyHz = signedBin*fs/fftLength;
end
