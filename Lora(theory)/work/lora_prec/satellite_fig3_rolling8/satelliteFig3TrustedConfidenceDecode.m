function result = satelliteFig3TrustedConfidenceDecode(rxSymbols,config,knownWaveformBins)
%SATELLITEFIG3TRUSTEDCONFIDENCEDECODE Receiver-only confidence pilot design.
%   1) detect SenLoRa candidates from the eight-preamble bootstrap;
%   2) retain one candidate per code block in quarantine;
%   3) at sufficiently high *estimated* SNR, use only two early, strongly
%      supported anchors to re-compensate the complete frame;
%   4) promote later symbols only when their label survives the independent
%      recheck and their soft-Hamming codeword margin is sufficient.
%   Neither this interface nor any called decision function receives payload
%   labels, true Doppler, true phase, or injected SNR.

nSymbols = size(rxSymbols,1);
bootstrapCount = numel(knownWaveformBins);
if bootstrapCount ~= config.bootstrapPilotCount
    error('SatelliteFig3:TrustedConfidenceBootstrap', ...
        'The trusted-confidence design requires the configured eight-symbol preamble.');
end

bootstrapTracker = satelliteFig3RollingPilotTracker(rxSymbols,config,knownWaveformBins);
firstSoft = satelliteFig3SenLoRaConfidence(bootstrapTracker.compensatedSymbols,config, ...
    AmendLlrMix=config.amendLlrMix);
firstFeatures = satelliteFig3PilotConfidenceFeatures(bootstrapTracker,firstSoft,config);
estimatedSnrDb = -10*log10(max(firstSoft.noisePower,eps));
[policyEnabled,anchorMargin,promotionMargin,policyName] = ...
    localPolicy(estimatedSnrDb,config);

firstEligible = localEligible(firstFeatures,firstSoft,config);
% Quarantine is deliberately broader than promotion: retain the best
% receiver-visible candidate from every code block for a possible later
% recheck, even if it is currently too weak to influence Doppler tracking.
quarantinePayload = localOnePerBlock(true(size(firstEligible)), ...
    firstFeatures,config,Inf);
anchorPayload = false(size(firstEligible));
if policyEnabled
    anchorEligible = firstEligible & ...
        firstFeatures.codewordMargin >= anchorMargin;
    anchorPayload = localOnePerBlock(anchorEligible,firstFeatures,config, ...
        config.confidenceAnchorBlockCount);
end
% One noisy anchor can perturb the frequency-rate fit over the complete
% frame.  Require two independent code-block anchors before replay; a lone
% candidate remains quarantined and cannot change the Doppler state.
recheckEnabled = sum(anchorPayload) >= config.confidenceMinimumAnchorCount;
if ~recheckEnabled
    anchorPayload(:) = false;
end
anchorMask = false(nSymbols,1);
anchorMask(firstFeatures.payloadRows) = anchorPayload;

% Re-play the *complete* received frame from its first sample.  The eight
% known preamble symbols initialise phase/CFO again before any accepted
% anchor is encountered; this is not a local correction beginning at an
% anchor's symbol index.
recheckTracker = satelliteFig3RollingPilotTracker(rxSymbols,config,knownWaveformBins, ...
    AcceptedMask=anchorMask, ...
    PilotConfidence=firstSoft.confidence, ...
    PilotThreshold=firstSoft.finalTauGlobal, ...
    DecisionWaveformBins=firstSoft.decodedWaveformBins);
secondSoft = satelliteFig3SenLoRaConfidence(recheckTracker.compensatedSymbols,config, ...
    PreviousTauGlobal=firstSoft.finalTauGlobal,AmendLlrMix=config.amendLlrMix);
secondFeatures = satelliteFig3PilotConfidenceFeatures(recheckTracker,secondSoft,config);
payloadRows = secondFeatures.payloadRows;
stableLabel = firstSoft.decodedWaveformBins(payloadRows) == ...
    secondSoft.decodedWaveformBins(payloadRows);
secondEligible = localEligible(secondFeatures,secondSoft,config) & stableLabel;

promotedPayload = false(size(secondEligible));
if recheckEnabled && policyEnabled
    promotable = secondEligible & ...
        secondFeatures.codewordMargin >= promotionMargin;
    % One promoted virtual pilot per Hamming/interleaving block avoids
    % correlated decisions entering the Doppler fit as independent points.
    promotedPayload = localOnePerBlock(promotable,secondFeatures,config,Inf);
end
promotedMask = false(nSymbols,1);
promotedMask(1:bootstrapCount) = true;
promotedMask(payloadRows) = promotedPayload;
quarantineMask = false(nSymbols,1);
quarantineMask(payloadRows) = quarantinePayload;

% A promoted virtual pilot has been independently checked after anchor-based
% replay.  Re-play once more from the frame start so these pilots update the
% rolling eight-slot state only for later symbols, producing the cumulative
% compensation used by the BER receiver.
virtualPilotTracker = satelliteFig3RollingPilotTracker(rxSymbols,config,knownWaveformBins, ...
    AcceptedMask=promotedMask, ...
    PilotConfidence=secondSoft.confidence, ...
    PilotThreshold=secondSoft.finalTauGlobal, ...
    DecisionWaveformBins=secondSoft.decodedWaveformBins);
finalSoft = satelliteFig3SenLoRaConfidence(virtualPilotTracker.compensatedSymbols,config, ...
    PreviousTauGlobal=secondSoft.finalTauGlobal,AmendLlrMix=config.amendLlrMix);

result = struct( ...
    'detectedWaveformBins',finalSoft.decodedWaveformBins, ...
    'replayFromFrameStart',true, ...
    'estimatedSnrDb',estimatedSnrDb, ...
    'snrPromotionEnabled',policyEnabled, ...
    'confidencePolicy',policyName, ...
    'recheckEnabled',recheckEnabled, ...
    'quarantineMask',quarantineMask, ...
    'anchorMask',anchorMask, ...
    'promotedMask',promotedMask, ...
    'stableLabelMask',[true(bootstrapCount,1);stableLabel], ...
    'bootstrapTracker',bootstrapTracker, ...
    'recheckTracker',recheckTracker, ...
    'virtualPilotTracker',virtualPilotTracker, ...
    'firstSoft',firstSoft, 'secondSoft',secondSoft, 'finalSoft',finalSoft, ...
    'firstFeatures',firstFeatures, 'secondFeatures',secondFeatures);
end

function [enabled,anchorMargin,promotionMargin,name] = localPolicy(estimatedSnrDb,config)
if estimatedSnrDb >= config.confidencePromotionSnrDb
    enabled = true;
    anchorMargin = config.confidenceAnchorMargin;
    promotionMargin = config.confidencePromotionMargin;
    name = 'high_snr';
elseif abs(estimatedSnrDb-config.confidenceLowSnrCenterDb) <= ...
        config.confidenceLowSnrHalfWidthDb
    enabled = true;
    anchorMargin = config.confidenceLowSnrAnchorMargin;
    promotionMargin = config.confidenceLowSnrPromotionMargin;
    name = 'validated_minus20_window';
else
    enabled = false;
    anchorMargin = Inf;
    promotionMargin = Inf;
    name = 'quarantine_only';
end
end

function eligible = localEligible(features,soft,config)
eligible = features.candidateMask & features.softHardAgreement & ...
    ~features.residualAtBoundary & ...
    abs(features.residualOffsetBins) <= config.confidenceInnovationLimitBins & ...
    features.codewordMargin > 0 & soft.readyMask(features.payloadRows);
end

function selected = localOnePerBlock(eligible,features,config,maxBlocks)
nPayload = numel(eligible);
blockLength = 4+config.cr;
blockId = ceil((1:nPayload).'/blockLength);
selected = false(nPayload,1);
quality = log(max(features.confidenceRatio,eps)) + ...
    0.20*log(max(features.hardPeakRatio,1)) + ...
    0.10*log(max(features.residualPeakRatio,1)) + ...
    log1p(max(features.codewordMargin,0)) - ...
    0.5*abs(features.residualOffsetBins) + ...
    0.05*double(features.softHardAgreement);
for block = 1:min(max(blockId),maxBlocks)
    members = find(blockId == block & eligible);
    if isempty(members), continue; end
    [~,best] = max(quality(members));
    selected(members(best)) = true;
end
end
