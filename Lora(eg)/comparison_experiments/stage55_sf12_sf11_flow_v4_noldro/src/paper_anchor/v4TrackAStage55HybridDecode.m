function result=v4TrackAStage55HybridDecode(packet,c,p)
anchor=v4TrackAPointAnchor(packet,c);
if abs(anchor.cfoBins)>p.highShiftThresholdBins,result=v4TrackAStage55PreambleAdaptiveDecode(packet,c,p);result.receiverMode='HIGH_SHIFT_STATIC';else,result=v4TrackAStage55EightUpRateDecode(packet,c,p);result.receiverMode='LOW_SHIFT_DYNAMIC';end
result.algorithmVersion='Stage55-A-observable-regime-hybrid-v7';result.pointAnchor=anchor;
end
