function symbol = loraDetectSymbol(receivedUpchirp, spreadingFactor)
%LORADETECTSYMBOL Dechirp, FFT, and select the maximum-energy bin.

arguments
    receivedUpchirp double
    spreadingFactor (1,1) double {mustBeInteger, mustBeInRange(spreadingFactor, 5, 12)}
end

numSamples = 2^spreadingFactor;
receivedUpchirp = receivedUpchirp(:);
validateattributes(receivedUpchirp, {'numeric'}, {'numel', numSamples});
dechirped = receivedUpchirp.*loraPureDownchirp(spreadingFactor);
spectrum = fft(dechirped, numSamples);
[~, oneBasedBin] = max(abs(spectrum).^2);
symbol = oneBasedBin - 1;
end
