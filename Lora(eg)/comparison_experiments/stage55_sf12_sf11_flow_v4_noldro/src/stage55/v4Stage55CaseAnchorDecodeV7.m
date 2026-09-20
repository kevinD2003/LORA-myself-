function result = v4Stage55CaseAnchorDecodeV7(observation,common,c,parameters)
%V4STAGE55CASEANCHORDECODEV7 Robust observable regime guard.
pilots = observation.rxPhysical(1:c.bootstrapPilotCount,:);
classification = v4Stage55PreambleRegimeClassifier(pilots,c, ...
    MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
estimate = v4Stage55JointPreambleMlBootstrap(pilots,c, ...
    MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
if classification.largeCfoRegion
    result = v4HuangStaticDecode(observation,common,c);
    result.methodName = c.methodNames{2};
    result.algorithmVersion = 'Stage55-B-case-anchor-robust-regime-v7';
    result.caseRegime = 'noncoherent-large-CFO-huang-equivalent';
    result.staticFallbackExact = true;
    result.confidenceSymbolSource = 'not-applicable-static-fallback';
else
    bootstrap = v4Stage55BootstrapFromJointPreambleMl(common,estimate,c);
    result = v4Stage55Decode(observation,bootstrap,c,parameters, ...
        CrossFrameRateBinsPerSec=estimate.rateBinsPerSec, ...
        CrossFrameHistoryCount=1);
    result.algorithmVersion = 'Stage55-B-case-anchor-robust-regime-v7';
    result.caseRegime = 'noncoherent-central-CFO-joint-preamble-vp';
    result.staticFallbackExact = false;
    result.confidenceSymbolSource = ...
        'post-compensated tracker symbols via v4Stage55Decode';
    result.jointBootstrap = bootstrap;
end
result.preambleRegimeClassification = classification;
result.jointPreambleEstimate = estimate;
result.observableRateBinsPerSec = estimate.rateBinsPerSec;
result.staticCfoMagnitudeThresholdBins = ...
    classification.staticCfoMagnitudeThresholdBins;
result.usesPayloadTruth = false;result.usesOrbitTruth = false;
end
