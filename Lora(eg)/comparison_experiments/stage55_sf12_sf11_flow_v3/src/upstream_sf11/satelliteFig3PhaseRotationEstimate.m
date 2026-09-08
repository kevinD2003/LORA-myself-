function estimate = satelliteFig3PhaseRotationEstimate(symbolSamples, knownWaveformBin, config, options)
%SATELLITEFIG3PHASEROTATIONESTIMATE Signed CFO/residual estimate by rotation.
%   A residual exp(+j2*pi*e*n/M) produces signed raw FFT bin e for the
%   discrete chirp convention used in this project, hence CFO=e.

arguments
    symbolSamples (1,:) double
    knownWaveformBin (1,1) double {mustBeInteger,mustBeNonnegative}
    config (1,1) struct
    options.CandidateOffsets (:,1) double = zeros(0,1)
    options.LocalOnly (1,1) logical = false
    options.StepBins (1,1) double {mustBePositive} = 0.05
end

m = config.samplesPerSymbol;
if knownWaveformBin >= m || numel(symbolSamples) ~= m
    error('SatelliteFig3:InvalidRotationInput','Invalid known symbol or length.');
end
known = satelliteFig3ModulateSymbol(knownWaveformBin,config.sf);
tone = symbolSamples.*conj(known);
n = 0:m-1;
if isempty(options.CandidateOffsets)
    if options.LocalOnly
        candidates = config.residualSearchBins;
    else
        spectrum = fft(tone)/sqrt(m);
        [~,index] = max(abs(spectrum));
        rawBin = index-1;
        if rawBin >= m/2
            rawBin = rawBin-m;
        end
        coarseCfo = rawBin;
        candidates = (coarseCfo-1:options.StepBins:coarseCfo+1).';
    end
else
    candidates = options.CandidateOffsets;
    coarseCfo = NaN;
end
bank = exp(-1i*2*pi*candidates*n/m);
coherent = bank*tone.'/m;
metric = abs(coherent);
[peak,peakIndex] = max(metric);
offset = candidates(peakIndex);
if peakIndex > 1 && peakIndex < numel(candidates)
    localPower = metric(peakIndex-1:peakIndex+1).^2;
    denominator = localPower(1)-2*localPower(2)+localPower(3);
    if abs(denominator) > eps
        delta = 0.5*(localPower(1)-localPower(3))/denominator;
        delta = min(1,max(-1,delta));
        offset = offset + delta*(candidates(2)-candidates(1));
    end
end
background = true(size(metric));
background(max(1,peakIndex-1):min(numel(metric),peakIndex+1)) = false;
backgroundMetric = median(metric(background));
if isempty(backgroundMetric) || backgroundMetric <= 0
    backgroundMetric = peak;
end
coherentAtOffset = sum(tone.*exp(-1i*2*pi*offset*n/m))/m;
fittedTone = coherentAtOffset*exp(1i*2*pi*offset*n/m);
residualNoisePower = mean(abs(tone-fittedTone).^2);
coherentSignalPower = abs(coherentAtOffset)^2;
estimatedToneSnrLinear = coherentSignalPower/max(residualNoisePower,eps);
% CRLB for the frequency of a complex sinusoid with unknown amplitude and
% phase, expressed in full-symbol FFT bins.  This is a receiver-visible
% uncertainty estimate: it uses only the decided LoRa waveform and the
% residual samples, never the transmitted label or true Doppler.
frequencyStdBins = sqrt(3/(2*pi^2*max(estimatedToneSnrLinear,eps)*m));
estimate = struct( ...
    'offsetBins',offset, 'phaseRad',angle(coherentAtOffset), ...
    'peakMetric',peak, 'peakRatio',peak/max(backgroundMetric,eps), ...
    'peakAtBoundary',peakIndex == 1 || peakIndex == numel(candidates), ...
    'coarseCfoBins',coarseCfo, 'candidateOffsets',candidates, ...
    'coherentSignalPower',coherentSignalPower, ...
    'residualNoisePower',residualNoisePower, ...
    'estimatedToneSnrLinear',estimatedToneSnrLinear, ...
    'frequencyStdBins',frequencyStdBins);
end
