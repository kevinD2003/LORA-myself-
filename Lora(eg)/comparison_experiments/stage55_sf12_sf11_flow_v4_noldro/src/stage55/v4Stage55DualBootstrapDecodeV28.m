function result=v4Stage55DualBootstrapDecodeV28(observation,commonBootstrap,crossBootstrap,c,lowP,highP,options)
arguments
 observation (1,1) struct;commonBootstrap (1,1) struct;crossBootstrap (1,1) struct;c (1,1) struct;lowP (1,1) struct;highP (1,1) struct
 options.CommonRateBinsPerSec (1,1) double=NaN;options.CommonHistoryCount (1,1) double=0
 options.CrossRateBinsPerSec (1,1) double=NaN;options.CrossHistoryCount (1,1) double=0
end
gain=commonBootstrap.peakMetric/(c.bootstrapPilotCount*commonBootstrap.noisePower);
hypothesisCount=35;threshold=1.5*log(c.dataAlphabetSize*hypothesisCount);
if gain>=threshold
 result=v4Stage55CausalBlockBankDecodeV17(observation,commonBootstrap,c,highP, ...
  CrossFrameRateBinsPerSec=options.CommonRateBinsPerSec,CrossFrameHistoryCount=options.CommonHistoryCount);
 regime='common-bootstrap-wide-bank';profile='B-param-v02';
else
 result=v4Stage55CrossAnchoredDualBlockDecodeV21(observation,crossBootstrap,c,lowP, ...
  CrossFrameRateBinsPerSec=options.CrossRateBinsPerSec,CrossFrameHistoryCount=options.CrossHistoryCount);
 regime='cross-bootstrap-dual-block';profile='B-param-v01';
end
result.algorithmVersion='Stage55-B-unquantized-theory-gate-v28';result.preambleProcessingGain=gain;
result.regimeThreshold=threshold;result.regimeThresholdFormula='1.5*ln(4096*35)';
result.observableRegime=regime;result.receiverParameterProfile=profile;result.virtualPilotAccepted=result.tracker.pilotAccepted;
result.usesPayloadTruth=false;result.usesOrbitTruth=false;
end
