function result = v4Stage55CaseProfileDecodeV8(observation,common,c,parameters,caseProfile)
%V4STAGE55CASEPROFILEDECODEV8 User-authorized known-case profile selection.
arguments
    observation (1,1) struct
    common (1,1) struct
    c (1,1) struct
    parameters (1,1) struct
    caseProfile (1,1) string {mustBeMember(caseProfile, ...
        ["case1-static","case2-dynamic"])}
end
if caseProfile == "case1-static"
    result = v4HuangStaticDecode(observation,common,c);
    result.methodName = c.methodNames{2};
    result.caseRegime = 'authorized-case1-huang-equivalent';
    result.staticFallbackExact = true;
    result.confidenceSymbolSource = 'not-applicable-static-profile';
else
    pilots = observation.rxPhysical(1:c.bootstrapPilotCount,:);
    estimate = v4Stage55JointPreambleMlBootstrap(pilots,c, ...
        MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
    bootstrap = v4Stage55BootstrapFromJointPreambleMl(common,estimate,c);
    result = v4Stage55Decode(observation,bootstrap,c,parameters, ...
        CrossFrameRateBinsPerSec=estimate.rateBinsPerSec, ...
        CrossFrameHistoryCount=1);
    result.caseRegime = 'authorized-case2-joint-preamble-vp';
    result.staticFallbackExact = false;
    result.confidenceSymbolSource = ...
        'post-compensated tracker symbols via v4Stage55Decode';
    result.jointBootstrap = bootstrap;
    result.jointPreambleEstimate = estimate;
end
result.algorithmVersion = 'Stage55-B-known-case-profile-v8';
result.caseProfile = char(caseProfile);
result.usesKnownCaseProfile = true;
result.usesPayloadTruth = false;
result.usesOrbitTruth = false;
end
