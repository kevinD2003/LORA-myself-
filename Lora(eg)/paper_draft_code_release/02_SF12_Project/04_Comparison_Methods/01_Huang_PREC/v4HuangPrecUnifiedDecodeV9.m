function result=v4HuangPrecUnifiedDecodeV9(observation,c)
%V4HUANGPRECUNIFIEDDECODEV9 Equal-domain project-aligned Huang PREC.
%   The established preamble classifier selects the large-CFO static path
%   only when its likelihood exceeds the equal-size central-CFO domain.
%   Static processing is the frozen project Huang baseline; central/dynamic
%   processing preserves the senior source fixed-CFO receiver.

pilots=observation.rxPhysical(1:c.bootstrapPilotCount,:);
classification=v4Stage55PreambleRegimeClassifier(pilots,c, ...
    MaximumRateBinsPerSec=20);
staticSelected=classification.largeCfoRegion;
if staticSelected
    parameters=v4LoadMethodAlignedR3ParametersV1();
    common=v4CommonBootstrap(pilots,c, ...
        SearchStepBins=parameters.searchStepBins);
    result=v4HuangStaticDecode(observation,common,c);
    regime='equal-domain-large-cfo-static-observable';
else
    result=v4HuangPrecDecodeV3(observation,c);
    regime='equal-domain-central-source-fixed-cfo-observable';
end
modeEvidence=struct('selected',localMode(staticSelected), ...
    'staticSelected',staticSelected,'classification',classification, ...
    'usesCaseIdentity',false,'usesSnrInput',false,'usesTruth',false);
result.methodId='huang-prec-unified-v9';
result.algorithmVersion='Huang-PREC-equal-domain-continuous-phase-v9';
result.huangRegime=regime;result.modeEvidence=modeEvidence;
result.sameEntryAcrossCases=true;result.usesCaseIdentity=false;
result.usesSnrInput=false;result.usesPayloadTruth=false;
result.usesOrbitTruth=false;
end

function value=localMode(staticSelected)
if staticSelected,value='static';else,value='dynamic';end
end
