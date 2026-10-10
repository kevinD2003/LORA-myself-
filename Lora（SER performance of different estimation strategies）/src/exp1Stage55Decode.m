function result = exp1Stage55Decode(observation,common,config,enablePayloadVp)
%EXP1STAGE55DECODE Frozen Stage55 or its payload-VP-off ablation.

c = config.parent;
if enablePayloadVp
    result = v4Stage55UnifiedDecodeV16(observation,common,c);
    result.payloadVpEnabled = true;
    return
end

pilots = observation.rxPhysical(1:c.bootstrapPilotCount,:);
modeParameters = struct('maximumRateBinsPerSec',20, ...
    'modeLargeToCentralRatio',0.75);
modeEvidence = v4Stage55ObservableModeSelectorV10(pilots,c,modeParameters);
if modeEvidence.staticSelected
    result = v4HuangStaticDecode(observation,common,c);
    result.methodName = 'Stage55-VP-off';
    regime = 'huang-equivalent-static-observable-vp-off';
else
    candidates = v4BCalibrationCandidates();
    parameters = candidates(2);
    estimate = v4Stage55JointPreambleMlBootstrap(pilots,c, ...
        MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
    bootstrap = v4Stage55BootstrapFromJointPreambleMl(common,estimate,c);
    tracker = v4RollingTrackerPass(observation,bootstrap,c,parameters, ...
        false(c.payloadSymbolCount,1), ...
        InitialRateBinsPerSec=estimate.rateBinsPerSec);
    decoded = v4DecodePayload(tracker.compensatedData,c,bootstrap.noisePower);
    result = struct('methodName','Stage55-VP-off', ...
        'detectedPhysicalBins',decoded.hardPhysicalBins, ...
        'hardDecodedDataBits',decoded.hardDataBits, ...
        'softDecodedDataBits',decoded.softDataBits, ...
        'estimatedCfoBins',tracker.predictedCfoBins, ...
        'virtualPilotAccepted',false(c.payloadSymbolCount,1), ...
        'explicitMidambleAccepted',false(c.paperMidambleCount,1), ...
        'tracker',tracker,'bootstrap',bootstrap, ...
        'jointPreambleEstimate',estimate, ...
        'initialRateBinsPerSec',estimate.rateBinsPerSec, ...
        'usesPayloadFeedback',false,'usesDopplerRate',true, ...
        'usesPayloadTruth',false,'usesOrbitTruth',false, ...
        'fftCount',c.payloadSymbolCount);
    regime = 'joint-preamble-prediction-only-observable-vp-off';
end
result.algorithmVersion = 'Stage55-B-unified-observable-v16-vp-off';
result.methodId = 'stage55-unified-v16-vp-off';
result.stageRegime = regime;
result.modeEvidence = modeEvidence;
result.sameEntryAcrossCases = true;
result.usesCaseIdentity = false;
result.usesSnrInput = false;
result.usesPayloadTruth = false;
result.usesOrbitTruth = false;
result.payloadVpEnabled = false;
end

