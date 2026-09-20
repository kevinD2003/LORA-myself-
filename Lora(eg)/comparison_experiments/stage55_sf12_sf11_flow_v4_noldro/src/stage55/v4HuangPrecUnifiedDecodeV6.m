function result=v4HuangPrecUnifiedDecodeV6(observation,c)
%V4HUANGPRECUNIFIEDDECODEV6 Observable continuous-phase PREC adapter.
%   A single receiver entry is used in both cases. Large-CFO/static pilot
%   evidence selects the continuous-phase power-combined PREC front end;
%   central/dynamic evidence keeps the senior source's direct complex
%   preamble average and fixed-CFO payload processing. The selector uses
%   only the eight received preambles.

pilots=observation.rxPhysical(1:c.bootstrapPilotCount,:);
modeParameters=struct('maximumRateBinsPerSec',20, ...
    'modeLargeToCentralRatio',0.75);
modeEvidence=v4Stage55ObservableModeSelectorV10(pilots,c,modeParameters);
if modeEvidence.staticSelected
    result=v4HuangPrecCpDecodeV5(observation,c);
    regime='continuous-phase-static-observable';
else
    result=v4HuangPrecDecodeV3(observation,c);
    regime='source-fixed-cfo-dynamic-observable';
end
result.methodId='huang-prec-unified-v6';
result.algorithmVersion='Huang-PREC-unified-continuous-phase-v6';
result.huangRegime=regime;result.modeEvidence=modeEvidence;
result.sameEntryAcrossCases=true;result.usesCaseIdentity=false;
result.usesSnrInput=false;result.usesPayloadTruth=false;
result.usesOrbitTruth=false;
end
