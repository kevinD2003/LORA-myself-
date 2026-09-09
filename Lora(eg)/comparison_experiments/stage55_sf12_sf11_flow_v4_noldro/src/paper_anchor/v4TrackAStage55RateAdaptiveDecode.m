function result=v4TrackAStage55RateAdaptiveDecode(packet,config,parameters)
b=v4TrackATwoDownchirpBootstrap(packet,config,parameters.bootstrapStepBins);
if abs(b.rateBinsPerSec)<parameters.staticRateThresholdBinsPerSec
    result=v4TrackAStaticSubbinDecode(packet,config,b);
else
    result=v4TrackAStage55TwoDownRateDecode(packet,config,parameters);result.algorithmVersion='Stage55-A-rate-adaptive-subbin-v4';result.receiverMode='DYNAMIC_VP';
end
result.initialReceiverRateBinsPerSec=b.rateBinsPerSec;result.staticRateThresholdBinsPerSec=parameters.staticRateThresholdBinsPerSec;
end
