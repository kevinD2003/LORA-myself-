function result=v4TrackAStage55PreambleAdaptiveDecode(packet,config,parameters)
anchor=v4TrackAPointAnchor(packet,config);
if abs(anchor.cfoBins)>parameters.highShiftThresholdBins
    s=packet.schedule;pilots=zeros(8,config.samplesPerSymbol);for k=1:8,first=s.startSample(k)+1;pilots(k,:)=packet.rx(first:first+config.samplesPerSymbol-1);end
    b=v4CommonBootstrap(pilots,config,SearchStepBins=parameters.bootstrapStepBins);static=struct('cfoAtQuarterStartBins',mean(b.cfoBins));result=v4TrackAStaticSubbinDecode(packet,config,static);result.receiverMode='EIGHT_UPCHIRP_STATIC';result.preambleBootstrap=b;
else
    result=v4TrackAStage55TwoDownRateDecode(packet,config,parameters);result.receiverMode='TWO_DOWN_DYNAMIC_VP';
end
result.algorithmVersion='Stage55-A-preamble-adaptive-v5';result.highShiftThresholdBins=parameters.highShiftThresholdBins;result.pointAnchor=anchor;
end
