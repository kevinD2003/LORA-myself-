function estimate = satelliteFig3BootstrapEstimate(rxPilots, knownWaveformBins, config)
%SATELLITEFIG3BOOTSTRAPESTIMATE Joint large-CFO acquisition from known pilots.

pilotCount = numel(knownWaveformBins);
m = config.samplesPerSymbol;
if size(rxPilots,1) ~= pilotCount || size(rxPilots,2) ~= m
    error('SatelliteFig3:BootstrapShape','Pilot rows must have M samples.');
end
aggregatePower = zeros(1,m);
for k = 1:pilotCount
    known = satelliteFig3ModulateSymbol(knownWaveformBins(k),config.sf);
    aggregatePower = aggregatePower + abs(fft(rxPilots(k,:).*conj(known))).^2;
end
[~,index] = max(aggregatePower);
rawBin = index-1;
if rawBin >= m/2
    rawBin = rawBin-m;
end
coarseCfo = rawBin;
candidates = (coarseCfo-1:config.bootstrapSearchStepBins:coarseCfo+1).';
cfoBins = zeros(pilotCount,1);
phaseRad = zeros(pilotCount,1);
peakRatio = zeros(pilotCount,1);
for k = 1:pilotCount
    local = satelliteFig3PhaseRotationEstimate(rxPilots(k,:), ...
        knownWaveformBins(k),config,CandidateOffsets=candidates);
    cfoBins(k) = local.offsetBins;
    phaseRad(k) = local.phaseRad;
    peakRatio(k) = local.peakRatio;
end
localCfoBins = cfoBins;
localPhaseRad = phaseRad;
joint = satelliteFig3BootstrapJointPhaseEstimate( ...
    rxPilots,knownWaveformBins,config,coarseCfo);
% Use the continuous preamble phase fit for the tracking state.  The local
% phase-rotation estimates remain available for diagnostics and peak
% quality, but their independent noise makes the short-baseline rate fit
% much less stable.
cfoBins = joint.centerCfoBins;
phaseRad = joint.startPhaseRad;
estimate = struct('coarseCfoBins',coarseCfo,'cfoBins',cfoBins, ...
    'phaseRad',phaseRad,'peakRatio',peakRatio, ...
    'localCfoBins',localCfoBins,'localPhaseRad',localPhaseRad, ...
    'jointRateBinsPerSec',joint.rateBinsPerSec,'joint',joint, ...
    'aggregatePower',aggregatePower);
end
