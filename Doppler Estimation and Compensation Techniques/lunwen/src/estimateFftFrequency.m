function estimateHz = estimateFftFrequency( ...
    dechirpedTones, sampleRateHz, fftLength)
%ESTIMATEFFTFREQUENCY Estimate signed frequency using the native FFT grid.
% Each column is one dechirped tone. No zero-padding or interpolation is
% used, matching the reproduction protocol.

arguments
    dechirpedTones double
    sampleRateHz (1,1) double {mustBePositive, mustBeFinite}
    fftLength (1,1) double {mustBeInteger, mustBePositive} = ...
        size(dechirpedTones, 1)
end

validateattributes(dechirpedTones, {'numeric'}, {'2d', 'nonempty'});
validateattributes(sampleRateHz, {'numeric'}, {'scalar', 'positive'});
numSamples = size(dechirpedTones, 1);
if fftLength < numSamples
    error('estimateFftFrequency:FftTooShort', ...
        'FFT length cannot be shorter than the input.');
end
spectrum = fft(dechirpedTones, fftLength, 1);
[~, oneBasedBins] = max(abs(spectrum).^2, [], 1);
zeroBasedBins = oneBasedBins - 1;
signedBins = zeroBasedBins;
signedBins(zeroBasedBins >= fftLength/2) = ...
    signedBins(zeroBasedBins >= fftLength/2) - fftLength;
estimateHz = double(signedBins)*sampleRateHz/fftLength;
end
