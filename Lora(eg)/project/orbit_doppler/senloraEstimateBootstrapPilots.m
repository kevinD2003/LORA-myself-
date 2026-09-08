function estimate = senloraEstimateBootstrapPilots( ...
        rxPilotSymbols, knownPilotBins, sf, options)
%SENLORAESTIMATEBOOTSTRAPPILOTS Robust joint acquisition from known pilots.
%
% The integer CFO is acquired from the noncoherent sum of all known-pilot
% residual spectra.  Each pilot is then refined independently on a local
% phase-rotation grid.  Combining the coarse evidence prevents a single
% low-SNR noise peak from sending the four-pilot trajectory fit to an
% unrelated FFT bin; no payload decisions or simulation truth are used.

arguments
    rxPilotSymbols (:,:) double
    knownPilotBins (:,1) double
    sf (1,1) double {mustBeInteger,mustBePositive}
    options.Step (1,1) double {mustBePositive} = 0.1
    options.HalfWidthBins (1,1) double {mustBePositive} = 1.0
end

pilotCount = numel(knownPilotBins);
numSamples = 2^sf;
if size(rxPilotSymbols,1) ~= pilotCount || ...
        size(rxPilotSymbols,2) ~= numSamples
    error("SenLoRa:InvalidBootstrapWaveform", ...
        "rxPilotSymbols must contain one 2^SF row per known pilot.");
end

aggregatePower = zeros(1,numSamples);
for idx = 1:pilotCount
    knownWaveform = senloraModulateLoRaSymbol(knownPilotBins(idx),sf);
    residualTone = rxPilotSymbols(idx,:).*conj(knownWaveform);
    aggregatePower = aggregatePower + abs(fft(residualTone)).^2;
end
[~,coarseIndex] = max(aggregatePower);
coarseBin = coarseIndex-1;
if coarseBin >= numSamples/2
    coarseBin = coarseBin-numSamples;
end

localOffsets = (coarseBin-options.HalfWidthBins:options.Step: ...
    coarseBin+options.HalfWidthBins).';
cfoBins = zeros(pilotCount,1);
phaseStartRad = zeros(pilotCount,1);
peakRatio = zeros(pilotCount,1);
peakMetric = zeros(pilotCount,1);
for idx = 1:pilotCount
    [cfoBins(idx),~,peakRatio(idx),phaseStartRad(idx),details] = ...
        senloraPhaseRotationEstimate(rxPilotSymbols(idx,:), ...
        knownPilotBins(idx),sf,CandidateOffsets=localOffsets);
    peakMetric(idx) = details.peakMetric;
end

estimate = struct( ...
    "coarseCfoBin",coarseBin, ...
    "aggregatePower",aggregatePower, ...
    "candidateOffsets",localOffsets, ...
    "cfoBins",cfoBins, ...
    "phaseStartRad",phaseStartRad, ...
    "peakRatio",peakRatio, ...
    "peakMetric",peakMetric);
end
