function result=v4PaperMidamblePointUnifiedV6(observation,common,c)
%V4PAPERMIDAMBLEPOINTUNIFIEDV6 Observable legacy/trend Point receiver.
pilots=observation.rxPhysical(1:c.bootstrapPilotCount,:);
parameters=struct('maximumRateBinsPerSec',20, ...
    'modeLargeToCentralRatio',0.75);
modeEvidence=v4Stage55ObservableModeSelectorV10(pilots,c,parameters);
if modeEvidence.staticSelected
    result=v4PaperMidamblePointUnifiedV4(observation,common,c);
    regime='legacy-point-static-observable';
else
    result=v4PaperMidamblePointTrendDecodeV3(observation,c);
    regime='trend-point-dynamic-observable';
end
result.methodName=c.methodNames{3};
result.methodId='paper-midamble-adapted-v6';
result.algorithmVersion='Paper-Midamble-Point-unified-observable-v6';
result.paperRegime=regime;result.modeEvidence=modeEvidence;
result.sameEntryAcrossCases=true;result.usesCaseIdentity=false;
result.usesSnrInput=false;result.usesPayloadTruth=false;
result.usesOrbitTruth=false;
end
