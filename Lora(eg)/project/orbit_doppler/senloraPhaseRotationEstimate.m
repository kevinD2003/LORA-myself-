function [offsetEstimate, metric, peakRatio, phaseEstimate, details] = ...
    senloraPhaseRotationEstimate(symbolSamples, knownBin, sf, options)
%SENLORAPHASEROTATIONESTIMATE Estimate a LoRa CFO with PREC rotation.
%
% The estimator first obtains a signed integer-bin estimate from the FFT of
% the known-symbol residual, then searches a 0.1-bin local grid.  It is
% usable for both the large initial CFO and the small post-compensation
% residual.

arguments
    symbolSamples (1,:) double
    knownBin (1,1) double {mustBeInteger, mustBeNonnegative}
    sf (1,1) double {mustBeInteger, mustBePositive}
    options.CandidateOffsets (:,1) double = zeros(0,1)
    options.LocalOnly (1,1) logical = false
    options.Step (1,1) double {mustBePositive} = 0.1
end

numSamples = 2^sf;
if numel(symbolSamples) ~= numSamples
    error("SenLoRa:InvalidRotationSymbolLength", ...
        "symbolSamples must contain 2^SF samples.");
end
if knownBin >= numSamples
    error("SenLoRa:InvalidRotationBin", ...
        "knownBin must be in [0,2^SF-1].");
end

knownWaveform = senloraModulateLoRaSymbol(knownBin, sf);
residualTone = symbolSamples .* conj(knownWaveform);
sampleIndex = 0:(numSamples-1);
coarseBin = NaN;

if isempty(options.CandidateOffsets)
    if options.LocalOnly
        options.CandidateOffsets = (-0.5:options.Step:0.5).';
    else
        spectrum = fft(residualTone)/sqrt(numSamples);
        [~, peakIndex] = max(abs(spectrum));
        coarseBin = peakIndex-1;
        if coarseBin >= numSamples/2
            coarseBin = coarseBin-numSamples;
        end
        options.CandidateOffsets = coarseBin + ...
            (-0.5:options.Step:0.5).';
    end
else
    coarseBin = NaN;
end

rotationBank = exp(-1i*2*pi*options.CandidateOffsets*sampleIndex/numSamples);
coherentOutput = rotationBank*residualTone.'/numSamples;
metric = abs(coherentOutput);
[peakMetric, peakIndex] = max(metric);
offsetEstimate = options.CandidateOffsets(peakIndex);

if peakIndex > 1 && peakIndex < numel(options.CandidateOffsets)
    localPower = metric((peakIndex-1):(peakIndex+1)).^2;
    denominator = localPower(1)-2*localPower(2)+localPower(3);
    if abs(denominator) > eps
        fractionalIndex = 0.5*(localPower(1)-localPower(3))/denominator;
        fractionalIndex = min(max(fractionalIndex, -1), 1);
        spacing = options.CandidateOffsets(2)-options.CandidateOffsets(1);
        offsetEstimate = offsetEstimate+fractionalIndex*spacing;
    end
end

% The 0.1-bin rotation grid samples a broad coherent main lobe.  Comparing
% only adjacent grid points would report about 1.016 even for a perfect
% residual, so use a non-local background (the points at least two grid
% cells away from the peak) for the SenLoRa quality ratio.
backgroundMask = true(size(metric));
backgroundMask(max(1,peakIndex-1):min(numel(metric),peakIndex+1)) = false;
backgroundMetric = median(metric(backgroundMask));
if ~isfinite(backgroundMetric) || backgroundMetric <= 0
    backgroundMetric = max(metric);
end
peakRatio = peakMetric/max(backgroundMetric, eps);
coherentAtEstimate = sum(residualTone.*exp(-1i*2*pi* ...
    offsetEstimate*sampleIndex/numSamples))/numSamples;
phaseEstimate = angle(coherentAtEstimate);

details = struct( ...
    "candidateOffsets", options.CandidateOffsets, ...
    "residualTone", residualTone, ...
    "peakMetric", peakMetric, ...
    "backgroundMetric", backgroundMetric, ...
    "peakIndex", peakIndex, ...
    "coarseBin", coarseBin, ...
    "peakAtBoundary", peakIndex == 1 || ...
        peakIndex == numel(options.CandidateOffsets));
end
