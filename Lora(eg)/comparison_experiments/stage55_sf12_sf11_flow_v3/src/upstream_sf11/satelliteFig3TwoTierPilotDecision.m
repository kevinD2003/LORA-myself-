function decision = satelliteFig3TwoTierPilotDecision(tracker, soft, config, model, sampleSnrDb)
%SATELLITEFIG3TWOTIERPILOTDECISION Immediate and quarantined pilot classes.
%   Immediate pilots may update the rolling-8 tracker.  One best candidate
%   per code block is retained as provisional when no immediate pilot is
%   safe; provisional pilots never alter the receiver state on this pass.

gate = satelliteFig3ApplyConfidenceGate(tracker,soft,config,model,sampleSnrDb);
feature = gate.features;
nPayload = numel(feature.payloadRows);
blockLength = 4+config.cr;
blockId = ceil((1:nPayload).'/blockLength);

% High SNR demands a narrow innovation interval.  At low SNR no candidate
% is immediately trusted; the best candidate is quarantined per block.
if sampleSnrDb >= -18
    directPosterior = 0.995;
    innovationLimit = 0.22;
elseif sampleSnrDb >= -20
    directPosterior = 0.998;
    innovationLimit = 0.18;
else
    directPosterior = 1.1; % no direct low-SNR promotion
    innovationLimit = 0.15;
end
innovationPass = abs(feature.residualOffsetBins) <= innovationLimit;
immediate = feature.candidateMask & feature.softHardAgreement & ...
    ~feature.residualAtBoundary & innovationPass & ...
    gate.posterior >= directPosterior;

% At most one immediate pilot per Hamming/interleaving block.  This avoids
% correlated same-block decisions entering the Doppler fit together.
for block = 1:max(blockId)
    rows = find(blockId == block & immediate);
    if numel(rows) > 1
        [~,best] = max(gate.posterior(rows));
        immediate(rows) = false;
        immediate(rows(best)) = true;
    end
end

quality = gate.posterior + 0.08*log(max(feature.hardPeakRatio,1)) + ...
    0.05*log(max(feature.residualPeakRatio,1)) - ...
    0.30*abs(feature.residualOffsetBins) + ...
    0.03*double(feature.softHardAgreement);
provisional = false(nPayload,1);
for block = 1:max(blockId)
    rows = find(blockId == block);
    if any(immediate(rows)), continue; end
    preferred = rows(feature.candidateMask(rows));
    if isempty(preferred), preferred = rows; end
    [~,best] = max(quality(preferred));
    provisional(preferred(best)) = true;
end

immediateMask = false(numel(tracker.detectedWaveformBins),1);
provisionalMask = immediateMask;
immediateMask(feature.payloadRows) = immediate;
provisionalMask(feature.payloadRows) = provisional;
immediateMask(1:config.bootstrapPilotCount) = true;
decision = struct( ...
    'immediateMask',immediateMask, ...
    'provisionalMask',provisionalMask, ...
    'immediatePayload',immediate, ...
    'provisionalPayload',provisional, ...
    'posterior',gate.posterior, 'quality',quality, ...
    'innovationLimitBins',innovationLimit, ...
    'directPosteriorThreshold',directPosterior, ...
    'features',feature, 'sampleSnrDb',sampleSnrDb);
end
