function result = v4Stage55CaseAnchorDecodeV5(observation,common,c,parameters)
%V4STAGE55CASEANCHORDECODEV5 Observable static guard plus joint-rate VP.
%
% Near-static frames use the frozen Huang processing exactly.  Dynamic
% frames use a sample-level joint CFO/rate estimate from the eight known
% preambles and then the causal Stage55 virtual-pilot tracker.  Regime
% selection uses no case identifier, payload truth or orbit truth.

arguments
    observation (1,1) struct
    common (1,1) struct
    c (1,1) struct
    parameters (1,1) struct
end

pilots = observation.rxPhysical(1:c.bootstrapPilotCount,:);
estimate = v4Stage55JointPreambleMlBootstrap(pilots,c, ...
    MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
staticRateLimit = parameters.virtualPilotRateStdLimitBinsPerSec;

if abs(estimate.rateBinsPerSec) <= staticRateLimit
    result = v4HuangStaticDecode(observation,common,c);
    result.methodName = c.methodNames{2};
    result.algorithmVersion = 'Stage55-B-case-anchor-joint-preamble-v5';
    result.caseRegime = 'observable-near-static-huang-equivalent';
    result.staticFallbackExact = true;
    result.confidenceSymbolSource = 'not-applicable-static-fallback';
else
    bootstrap = v4Stage55BootstrapFromJointPreambleMl(common,estimate,c);
    result = v4Stage55Decode(observation,bootstrap,c,parameters, ...
        CrossFrameRateBinsPerSec=estimate.rateBinsPerSec, ...
        CrossFrameHistoryCount=1);
    result.algorithmVersion = 'Stage55-B-case-anchor-joint-preamble-v5';
    result.caseRegime = 'observable-dynamic-joint-preamble-vp';
    result.staticFallbackExact = false;
    result.confidenceSymbolSource = ...
        'post-compensated tracker symbols via v4Stage55Decode';
    result.jointBootstrap = bootstrap;
end

result.jointPreambleEstimate = estimate;
result.observableRateBinsPerSec = estimate.rateBinsPerSec;
result.staticRateLimitBinsPerSec = staticRateLimit;
result.usesPayloadTruth = false;
result.usesOrbitTruth = false;
end
