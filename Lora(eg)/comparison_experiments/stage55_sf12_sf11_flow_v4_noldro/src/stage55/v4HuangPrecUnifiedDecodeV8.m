function result=v4HuangPrecUnifiedDecodeV8(observation,c)
%V4HUANGPRECUNIFIEDDECODEV8 Frozen project-aligned Huang PREC entry.
%   Static evidence uses the same frozen continuous-phase Huang bootstrap
%   as the current project comparison path. Dynamic evidence preserves the
%   senior source's direct preamble average and frozen payload CFO.

pilots=observation.rxPhysical(1:c.bootstrapPilotCount,:);
modeParameters=struct('maximumRateBinsPerSec',20, ...
    'modeLargeToCentralRatio',0.75);
modeEvidence=v4Stage55ObservableModeSelectorV10(pilots,c,modeParameters);
if modeEvidence.staticSelected
    parameters=v4LoadMethodAlignedR3ParametersV1();
    common=v4CommonBootstrap(pilots,c, ...
        SearchStepBins=parameters.searchStepBins);
    result=v4HuangStaticDecode(observation,common,c);
    regime='frozen-project-continuous-phase-static-observable';
else
    result=v4HuangPrecDecodeV3(observation,c);
    regime='source-fixed-cfo-dynamic-observable';
end
result.methodId='huang-prec-unified-v8';
result.algorithmVersion='Huang-PREC-frozen-project-continuous-phase-v8';
result.huangRegime=regime;result.modeEvidence=modeEvidence;
result.sameEntryAcrossCases=true;result.usesCaseIdentity=false;
result.usesSnrInput=false;result.usesPayloadTruth=false;
result.usesOrbitTruth=false;
end
