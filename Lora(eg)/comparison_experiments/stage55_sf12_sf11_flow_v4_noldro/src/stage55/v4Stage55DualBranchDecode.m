function result=v4Stage55DualBranchDecode(observation,bootstrap,c,p,options)
arguments
    observation (1,1) struct
    bootstrap (1,1) struct
    c (1,1) struct
    p (1,1) struct
    options.CrossFrameRateBinsPerSec (1,1) double=NaN
    options.CrossFrameHistoryCount (1,1) double=0
end
vp=v4Stage55Decode(observation,bootstrap,c,p,CrossFrameRateBinsPerSec=options.CrossFrameRateBinsPerSec,CrossFrameHistoryCount=options.CrossFrameHistoryCount);
plainTracker=v4RollingTrackerPass(observation,bootstrap,c,p,false(c.payloadSymbolCount,1),InitialRateBinsPerSec=options.CrossFrameRateBinsPerSec);plain=v4DecodePayload(plainTracker.compensatedData,c,bootstrap.noisePower);vpDecoded=v4DecodePayload(vp.tracker.compensatedData,c,bootstrap.noisePower);
chooseVp=vp.tracker.decisionPeakRatio>=plainTracker.decisionPeakRatio;detected=plain.hardPhysicalBins;detected(chooseVp)=vp.detectedPhysicalBins(chooseVp);estimated=plainTracker.predictedCfoBins;estimated(chooseVp)=vp.estimatedCfoBins(chooseVp);
hard=plain.hardDataBits;soft=plain.softDataBits;blockChoice=false(c.hammingBlockCount,1);table=v4Hamming74Table();signed=2*double(table)-1;
for block=1:c.hammingBlockCount
    vpScore=0;plainScore=0;for row=1:12,vpScore=vpScore+max(signed*reshape(vpDecoded.rawCodeLlr(row,:,block),7,1));plainScore=plainScore+max(signed*reshape(plain.rawCodeLlr(row,:,block),7,1));end
    if vpScore>=plainScore,hard(:,:,block)=vpDecoded.hardDataBits(:,:,block);soft(:,:,block)=vpDecoded.softDataBits(:,:,block);blockChoice(block)=true;end
end
result=struct('methodName','Stage55-VP-quality-CR3-SF12-noLDRO','algorithmVersion','Stage55-B-dual-branch-visible-metric-v1','detectedPhysicalBins',detected,'hardDecodedDataBits',hard,'softDecodedDataBits',soft,'estimatedCfoBins',estimated,'virtualPilotAccepted',vp.virtualPilotAccepted,'explicitMidambleAccepted',false(c.paperMidambleCount,1),'pilotFirstEffectivePhysicalRow',vp.pilotFirstEffectivePhysicalRow,'pilotAvailabilityPhysicalRow',vp.pilotAvailabilityPhysicalRow,'activeHistoryCount',vp.activeHistoryCount,'phasePairUsed',vp.phasePairUsed,'iterations',vp.iterations,'tracker',vp.tracker,'symbolVpBranch',chooseVp,'blockVpBranch',blockChoice,'usesPayloadTruth',false,'usesOrbitTruth',false,'usesSoftInformationOnlyForAdmission',true,'fftCount',vp.fftCount+c.payloadSymbolCount);
end
