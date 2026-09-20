function estimate = v4PaperIntegerPointEstimate(symbolSamples,knownPhysicalBin,c)
%V4PAPERINTEGERPOINTESTIMATE Full-FFT integer-bin Point estimator.
arguments
    symbolSamples (1,:) double
    knownPhysicalBin (1,1) double {mustBeInteger,mustBeNonnegative}
    c (1,1) struct
end
if numel(symbolSamples) ~= c.samplesPerSymbol
    error('V4:PaperPointLength','One complete SF12 chirp is required.');
end
known = v4ModulateSymbol(knownPhysicalBin,c);
spectrum = fft(symbolSamples.*conj(known));
energy = abs(spectrum).^2;
[peakMetric,index] = max(energy);
signedBin = index-1;
if signedBin >= c.samplesPerSymbol/2
    signedBin = signedBin-c.samplesPerSymbol;
end
ordered = sort(energy,'descend');
estimate = struct('offsetBins',signedBin,'peakMetric',peakMetric, ...
    'peakRatio',peakMetric/max(ordered(2),eps),'integerOnly',true, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end
