function estimate = v4PhaseRotationEstimate(symbolSamples,knownPhysicalBin,config,candidates)
%V4PHASEROTATIONESTIMATE Receiver-only signed CFO and start-phase estimate.

arguments
    symbolSamples (1,:) double
    knownPhysicalBin (1,1) double {mustBeInteger,mustBeNonnegative}
    config (1,1) struct
    candidates (:,1) double
end

m = config.samplesPerSymbol;
if knownPhysicalBin >= m || numel(symbolSamples) ~= m || isempty(candidates)
    error('V4:InvalidRotationInput','Known symbol, sample length, or candidates invalid.');
end
known = v4ModulateSymbol(knownPhysicalBin,config);
tone = symbolSamples.*conj(known);
n = 0:m-1;
bank = exp(-1i*2*pi*candidates*n/m);
coherent = bank*tone.'/m;
metric = abs(coherent);
[peak,peakIndex] = max(metric);
offsetBins = candidates(peakIndex);
if peakIndex > 1 && peakIndex < numel(candidates)
    localPower = metric(peakIndex-1:peakIndex+1).^2;
    denominator = localPower(1)-2*localPower(2)+localPower(3);
    if abs(denominator) > eps
        delta = 0.5*(localPower(1)-localPower(3))/denominator;
        delta = min(1,max(-1,delta));
        offsetBins = offsetBins+delta*(candidates(2)-candidates(1));
    end
end
coherentAtOffset = mean(tone.*exp(-1i*2*pi*offsetBins*n/m));
background = true(size(metric));
background(max(1,peakIndex-1):min(numel(metric),peakIndex+1)) = false;
backgroundMetric = median(metric(background));
if isempty(backgroundMetric) || backgroundMetric <= 0
    backgroundMetric = peak;
end
estimate = struct('offsetBins',offsetBins, ...
    'phaseRad',angle(coherentAtOffset), ...
    'peakMetric',peak,'peakRatio',peak/max(backgroundMetric,eps), ...
    'peakAtBoundary',peakIndex == 1 || peakIndex == numel(candidates), ...
    'candidateOffsets',candidates);
end
