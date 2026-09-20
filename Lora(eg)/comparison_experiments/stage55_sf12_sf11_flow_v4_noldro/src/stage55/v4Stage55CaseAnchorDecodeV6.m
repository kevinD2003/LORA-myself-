function result = v4Stage55CaseAnchorDecodeV6(observation,common,c,parameters)
%V4STAGE55CASEANCHORDECODEV6 Observable CFO-regime guard plus joint-rate VP.
%
% This two-anchor diagnostic contains a large-CFO near-static region and a
% near-zero-CFO high-rate region.  The sample-level joint preamble estimate
% selects the region without a case identifier, payload truth or orbit
% truth.  Large-CFO frames use the frozen Huang processing exactly; central
% frames use the Stage55 joint-rate virtual-pilot tracker.

arguments
    observation (1,1) struct
    common (1,1) struct
    c (1,1) struct
    parameters (1,1) struct
end

pilots = observation.rxPhysical(1:c.bootstrapPilotCount,:);
estimate = v4Stage55JointPreambleMlBootstrap(pilots,c, ...
    MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
staticCfoMagnitudeThreshold = c.samplesPerSymbol/8;

if abs(estimate.cfoAtFirstPreambleStartBins) >= ...
        staticCfoMagnitudeThreshold
    result = v4HuangStaticDecode(observation,common,c);
    result.methodName = c.methodNames{2};
    result.algorithmVersion = 'Stage55-B-case-anchor-CFO-regime-v6';
    result.caseRegime = 'observable-large-CFO-huang-equivalent';
    result.staticFallbackExact = true;
    result.confidenceSymbolSource = 'not-applicable-static-fallback';
else
    bootstrap = v4Stage55BootstrapFromJointPreambleMl(common,estimate,c);
    result = v4Stage55Decode(observation,bootstrap,c,parameters, ...
        CrossFrameRateBinsPerSec=estimate.rateBinsPerSec, ...
        CrossFrameHistoryCount=1);
    result.algorithmVersion = 'Stage55-B-case-anchor-CFO-regime-v6';
    result.caseRegime = 'observable-central-CFO-joint-preamble-vp';
    result.staticFallbackExact = false;
    result.confidenceSymbolSource = ...
        'post-compensated tracker symbols via v4Stage55Decode';
    result.jointBootstrap = bootstrap;
end

result.jointPreambleEstimate = estimate;
result.observableRateBinsPerSec = estimate.rateBinsPerSec;
result.staticCfoMagnitudeThresholdBins = staticCfoMagnitudeThreshold;
result.usesPayloadTruth = false;
result.usesOrbitTruth = false;
end
