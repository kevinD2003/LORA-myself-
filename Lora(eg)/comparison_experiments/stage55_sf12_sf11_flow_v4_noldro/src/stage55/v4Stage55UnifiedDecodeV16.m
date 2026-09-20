function result=v4Stage55UnifiedDecodeV16(observation,common,c)
%V4STAGE55UNIFIEDDECODEV16 Observable unified historical dynamic VP path.
pilots=observation.rxPhysical(1:c.bootstrapPilotCount,:);
modeParameters=struct('maximumRateBinsPerSec',20, ...
    'modeLargeToCentralRatio',0.75);
modeEvidence=v4Stage55ObservableModeSelectorV10(pilots,c,modeParameters);
if modeEvidence.staticSelected
    result=v4HuangStaticDecode(observation,common,c);
    result.methodName=c.methodNames{2};regime='huang-equivalent-static-observable';
else
    p=v4BCalibrationCandidates();p=p(2);
    estimate=v4Stage55JointPreambleMlBootstrap(pilots,c, ...
        MaximumRateBinsPerSec=p.maximumRateBinsPerSec);
    bootstrap=v4Stage55BootstrapFromJointPreambleMl(common,estimate,c);
    result=v4Stage55Decode(observation,bootstrap,c,p, ...
        CrossFrameRateBinsPerSec=estimate.rateBinsPerSec, ...
        CrossFrameHistoryCount=1);
    result.jointBootstrap=bootstrap;result.jointPreambleEstimate=estimate;
    regime='joint-preamble-vp-dynamic-observable';
end
result.algorithmVersion='Stage55-B-unified-observable-v16';
result.methodId='stage55-unified-v16';result.stageRegime=regime;
result.modeEvidence=modeEvidence;result.sameEntryAcrossCases=true;
result.usesCaseIdentity=false;result.usesSnrInput=false;
result.usesPayloadTruth=false;result.usesOrbitTruth=false;
end
