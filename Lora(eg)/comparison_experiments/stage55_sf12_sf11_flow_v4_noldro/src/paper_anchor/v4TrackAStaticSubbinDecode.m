function result=v4TrackAStaticSubbinDecode(packet,config,bootstrap)
s=packet.schedule;cfo=bootstrap.cfoAtQuarterStartBins;phase=0;detected=nan(23,1);estimated=nan(23,1);
for row=s.quarterDownRow:numel(s.kind),first=s.startSample(row)+1;x=packet.rx(first:first+s.sampleCount(row)-1).';duration=numel(x)/config.sampleRateHz;n=0:numel(x)-1;y=x.*exp(-1i*(phase+2*pi*cfo*n/config.samplesPerSymbol));if s.kind(row)=="data",d=s.dataIndex(row);decision=v4SymbolLikelihood(y,config,packet.noiseVariance);detected(d)=decision.physicalBin;estimated(d)=cfo;end;phase=mod(phase+2*pi*cfo*duration/config.symbolDurationSec,2*pi);end
result=struct('methodName','Stage55-VP-quality-SER-SF12-noLDRO','algorithmVersion','Stage55-A-rate-adaptive-subbin-v4','receiverMode','STATIC_SUBBIN','detectedPhysicalBins',detected,'estimatedCfoBins',estimated,'virtualPilotAccepted',false(23,1),'vpUsedLabel',nan(23,1),'bootstrap',bootstrap,'usesTruth',false,'usesHamming',false,'usesMidambleObservation',false);
end
