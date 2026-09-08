function result=v4TrackAStage55TwoDownRateDecode(packet,config,parameters)
% Exploratory R6 receiver with two-downchirp sub-bin initial rate.
s=packet.schedule;b=v4TrackATwoDownchirpBootstrap(packet,config,parameters.bootstrapStepBins);cfo=b.cfoAtQuarterStartBins;rate=max(-parameters.maximumRateBinsPerSec,min(parameters.maximumRateBinsPerSec,b.rateBinsPerSec));phase=0;history=repmat(struct('measurementTimeSec',0,'cfoCandidateBins',0,'peakRatio',0),0,1);detected=nan(23,1);estimated=nan(23,1);accepted=false(23,1);labels=nan(23,1);release=nan(23,1);effective=nan(23,1);rejected=0;lost=false;
for row=s.quarterDownRow:numel(s.kind)
    first=s.startSample(row)+1;x=packet.rx(first:first+s.sampleCount(row)-1).';duration=numel(x)/config.sampleRateHz;center=cfo+rate*duration/2;y=localCompensate(x,phase,center,rate,config);oldCfo=cfo;oldRate=rate;
    if s.kind(row)=="data"
        d=s.dataIndex(row);decision=v4SymbolLikelihood(y,config,packet.noiseVariance);detected(d)=decision.physicalBin;estimated(d)=center;
        if ~lost
            residual=v4PhaseRotationEstimate(y,decision.physicalBin,config,(-1:parameters.residualStepBins:1).');q=v4TrackASymbolQuality(decision,residual,parameters);
            if q.accept
                measurement=struct('measurementTimeSec',s.centerTimeOffsetSec(row),'cfoCandidateBins',center+residual.offsetBins,'peakRatio',q.peakRatio);proposed=[history;measurement];if numel(proposed)>8,proposed=proposed(end-7:end);end
                if numel(proposed)>=2,fit=v4TrackACommittedHistoryFit(proposed,(s.startSample(row)+s.sampleCount(row))/config.sampleRateHz,parameters);valid=fit.withinRateBound&&fit.withinResidualBound;else,fit=struct('cfoBins',measurement.cfoCandidateBins+rate*duration/2,'rateBinsPerSec',rate);valid=true;end
                if valid,accepted(d)=true;labels(d)=decision.physicalBin;release(d)=(s.startSample(row)+s.sampleCount(row))/config.sampleRateHz;if row<numel(s.kind),effective(d)=s.startSample(row+1)/config.sampleRateHz;end;history=proposed;cfo=fit.cfoBins;rate=fit.rateBinsPerSec;rejected=0;else,rejected=rejected+1;end
            else,rejected=rejected+1;end
            if rejected>=3,lost=true;end
        end
    end
    phase=mod(phase+2*pi*(oldCfo*duration/config.symbolDurationSec+0.5*oldRate*duration^2/config.symbolDurationSec),2*pi);if ~(s.kind(row)=="data"&&accepted(s.dataIndex(row))),cfo=oldCfo+oldRate*duration;end
end
result=struct('methodName','Stage55-VP-quality-SER-SF12-noLDRO','algorithmVersion','Stage55-A-two-downchirp-subbin-rate-v3','detectedPhysicalBins',detected,'estimatedCfoBins',estimated,'virtualPilotAccepted',accepted,'vpUsedLabel',labels,'releaseAtSec',release,'firstEffectiveTimeSec',effective,'bootstrap',b,'finalLost',lost,'usesTruth',false,'usesHamming',false,'usesMidambleObservation',false);
end
function y=localCompensate(x,phase,cfo,rate,c),n=0:numel(x)-1;t=n/c.sampleRateHz;duration=numel(x)/c.sampleRateHz;start=cfo-rate*duration/2;y=x.*exp(-1i*(phase+2*pi*(start*t/c.symbolDurationSec+0.5*rate*t.^2/c.symbolDurationSec)));end
