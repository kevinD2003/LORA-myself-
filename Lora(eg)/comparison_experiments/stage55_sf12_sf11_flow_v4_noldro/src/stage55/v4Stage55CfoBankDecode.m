function result=v4Stage55CfoBankDecode(observation,bootstrap,c,p,options)
arguments
    observation (1,1) struct
    bootstrap (1,1) struct
    c (1,1) struct
    p (1,1) struct
    options.CrossFrameRateBinsPerSec (1,1) double=NaN
    options.CrossFrameHistoryCount (1,1) double=0
end
offsets=(-2:2).';detectedBank=zeros(112,5);estimatedBank=zeros(112,5);peakBank=zeros(112,5);acceptedBank=false(112,5);appliedBank=nan(112,5);availabilityBank=nan(112,5);activeBank=zeros(112,5);phaseBank=false(112,5);hardBank=false(12,4,16,5);softBank=false(12,4,16,5);scoreBank=zeros(16,5);fftTotal=0;table=v4Hamming74Table();signed=2*double(table)-1;
for h=1:5
    b=bootstrap;b.epsilonHatBins=bootstrap.epsilonHatBins+offsets(h);b.cfoBins=bootstrap.cfoBins+offsets(h);
    if h==3
        branch=v4Stage55Decode(observation,b,c,p,CrossFrameRateBinsPerSec=options.CrossFrameRateBinsPerSec,CrossFrameHistoryCount=options.CrossFrameHistoryCount);tracker=branch.tracker;d=v4DecodePayload(tracker.compensatedData,c,bootstrap.noisePower);acceptedBank(:,h)=branch.virtualPilotAccepted;appliedBank(:,h)=branch.pilotFirstEffectivePhysicalRow;availabilityBank(:,h)=branch.pilotAvailabilityPhysicalRow;activeBank(:,h)=branch.activeHistoryCount;phaseBank(:,h)=branch.phasePairUsed;fftTotal=fftTotal+branch.fftCount+c.payloadSymbolCount;
    else
        tracker=v4RollingTrackerPass(observation,b,c,p,false(c.payloadSymbolCount,1),InitialRateBinsPerSec=options.CrossFrameRateBinsPerSec);d=v4DecodePayload(tracker.compensatedData,c,bootstrap.noisePower);availabilityBank(:,h)=tracker.pilotAvailabilityPhysicalRow;activeBank(:,h)=tracker.activeHistoryCount;fftTotal=fftTotal+2*c.payloadSymbolCount;
    end
    detectedBank(:,h)=d.hardPhysicalBins;estimatedBank(:,h)=tracker.predictedCfoBins;peakBank(:,h)=tracker.decisionPeakRatio;hardBank(:,:,:,h)=d.hardDataBits;softBank(:,:,:,h)=d.softDataBits;
    for block=1:16,for row=1:12,scoreBank(block,h)=scoreBank(block,h)+max(signed*reshape(d.rawCodeLlr(row,:,block),7,1));end,end
    clear branch tracker d b
end
[~,blockBranch]=max(scoreBank,[],2);cumulativeScore=cumsum(scoreBank,1);symbolBranch=zeros(112,1);activeBranch=3;
for block=1:16,rows=(block-1)*7+(1:7);symbolBranch(rows)=activeBranch;[~,activeBranch]=max(cumulativeScore(block,:));end
detected=zeros(112,1);estimated=zeros(112,1);accepted=false(112,1);applied=nan(112,1);availability=nan(112,1);active=zeros(112,1);phasePair=false(112,1);
for i=1:112,h=symbolBranch(i);detected(i)=detectedBank(i,h);estimated(i)=estimatedBank(i,h);accepted(i)=acceptedBank(i,h);applied(i)=appliedBank(i,h);availability(i)=availabilityBank(i,h);active(i)=activeBank(i,h);phasePair(i)=phaseBank(i,h);end
hard=false(12,4,16);soft=false(12,4,16);for block=1:16,h=blockBranch(block);hard(:,:,block)=hardBank(:,:,block,h);soft(:,:,block)=softBank(:,:,block,h);end;[~,globalBranch]=max(sum(scoreBank,1));globalHard=hardBank(:,:,:,globalBranch);globalSoft=softBank(:,:,:,globalBranch);
result=struct('methodName','Stage55-VP-quality-CR3-SF12-noLDRO','algorithmVersion','Stage55-B-cumulative-block-CFO-bank-v4','detectedPhysicalBins',detected,'hardDecodedDataBits',hard,'softDecodedDataBits',soft,'estimatedCfoBins',estimated,'virtualPilotAccepted',accepted,'explicitMidambleAccepted',false(c.paperMidambleCount,1),'pilotFirstEffectivePhysicalRow',applied,'pilotAvailabilityPhysicalRow',availability,'activeHistoryCount',active,'phasePairUsed',phasePair,'symbolBranch',symbolBranch,'blockBranch',blockBranch,'cumulativeScore',cumulativeScore,'globalBranch',globalBranch,'globalHardDataBits',globalHard,'globalSoftDataBits',globalSoft,'branchOffsets',offsets,'centralDetectedPhysicalBins',detectedBank(:,3),'centralEstimatedCfoBins',estimatedBank(:,3),'centralVirtualPilotAccepted',acceptedBank(:,3),'centralAppliedRow',appliedBank(:,3),'centralAvailabilityRow',availabilityBank(:,3),'centralActiveHistoryCount',activeBank(:,3),'centralPhasePairUsed',phaseBank(:,3),'usesPayloadTruth',false,'usesOrbitTruth',false,'fftCount',fftTotal);
end
