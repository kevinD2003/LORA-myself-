function result=v4TrackAStage55ConsensusHybridDecode(packet,c,p)
anchor=v4TrackAPointAnchor(packet,c);if abs(anchor.cfoBins)>p.highShiftThresholdBins,result=v4TrackAStage55PreambleAdaptiveDecode(packet,c,p);result.receiverMode='HIGH_SHIFT_STATIC';else,b=v4TrackAEightUpConsensusBootstrap(packet,c,p.bootstrapStepBins,p.maximumRateBinsPerSec);result=v4TrackAStage55FromPreambleRate(packet,c,p,b,'Stage55-A-consensus-rate-hybrid-v8');result.receiverMode='LOW_SHIFT_CONSENSUS_DYNAMIC';end;result.algorithmVersion='Stage55-A-consensus-rate-hybrid-v8';result.pointAnchor=anchor;
end
