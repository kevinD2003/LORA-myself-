function result=v4Stage55DualBootstrapDecodeV24( ...
        observation,commonBootstrap,crossBootstrap,c,lowP,highP,options)
%V4STAGE55DUALBOOTSTRAPDECODEV24 Observable bootstrap and profile selection.
arguments
    observation (1,1) struct
    commonBootstrap (1,1) struct
    crossBootstrap (1,1) struct
    c (1,1) struct
    lowP (1,1) struct
    highP (1,1) struct
    options.CommonRateBinsPerSec (1,1) double=NaN
    options.CommonHistoryCount (1,1) double=0
    options.CrossRateBinsPerSec (1,1) double=NaN
    options.CrossHistoryCount (1,1) double=0
end
processingGain=commonBootstrap.peakMetric/(c.bootstrapPilotCount*commonBootstrap.noisePower);
threshold=20;
if processingGain>=threshold
    result=v4Stage55CausalBlockBankDecodeV17(observation,commonBootstrap,c,highP, ...
        CrossFrameRateBinsPerSec=options.CommonRateBinsPerSec, ...
        CrossFrameHistoryCount=options.CommonHistoryCount);
    regime='common-bootstrap-wide-bank';profile='B-param-v02';
else
    result=v4Stage55CrossAnchoredDualBlockDecodeV21(observation,crossBootstrap,c,lowP, ...
        CrossFrameRateBinsPerSec=options.CrossRateBinsPerSec, ...
        CrossFrameHistoryCount=options.CrossHistoryCount);
    regime='cross-bootstrap-dual-block';profile='B-param-v01';
end
result.algorithmVersion='Stage55-B-observable-dual-bootstrap-v24';
result.preambleProcessingGain=processingGain;result.regimeThreshold=threshold;
result.observableRegime=regime;result.receiverParameterProfile=profile;
result.virtualPilotAccepted=result.tracker.pilotAccepted;
result.usesPayloadTruth=false;result.usesOrbitTruth=false;
end
