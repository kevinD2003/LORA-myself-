function result=v4Stage55CrossAnchoredDualBlockDecodeV21(observation,bootstrap,c,p,options)
%V4STAGE55CROSSANCHOREDDUALBLOCKDECODEV21 Block-causal VP/no-VP selector.
arguments
    observation (1,1) struct
    bootstrap (1,1) struct
    c (1,1) struct
    p (1,1) struct
    options.CrossFrameRateBinsPerSec (1,1) double=NaN
    options.CrossFrameHistoryCount (1,1) double=0
end

vp=v4Stage55Decode(observation,bootstrap,c,p, ...
    CrossFrameRateBinsPerSec=options.CrossFrameRateBinsPerSec, ...
    CrossFrameHistoryCount=options.CrossFrameHistoryCount);
plainTracker=v4RollingTrackerPass(observation,bootstrap,c,p, ...
    false(c.payloadSymbolCount,1), ...
    InitialRateBinsPerSec=options.CrossFrameRateBinsPerSec);
plain=v4DecodePayload(plainTracker.compensatedData,c,bootstrap.noisePower);
vpDecoded=v4DecodePayload(vp.tracker.compensatedData,c,bootstrap.noisePower);
table=v4Hamming74Table();
signed=2*double(table)-1;
blockChoice=false(c.hammingBlockCount,1);
blockScore=zeros(c.hammingBlockCount,2);
detected=zeros(c.payloadSymbolCount,1);
estimated=zeros(c.payloadSymbolCount,1);
hard=false(c.effectiveDataSf,4,c.hammingBlockCount);
soft=false(c.effectiveDataSf,4,c.hammingBlockCount);
for block=1:c.hammingBlockCount
    vpScore=0;
    plainScore=0;
    for row=1:c.effectiveDataSf
        vpScore=vpScore+max(signed*reshape(vpDecoded.rawCodeLlr(row,:,block),7,1));
        plainScore=plainScore+max(signed*reshape(plain.rawCodeLlr(row,:,block),7,1));
    end
    blockScore(block,:)=[plainScore vpScore];
    chooseVp=vpScore>=plainScore;
    blockChoice(block)=chooseVp;
    rows=(block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    if chooseVp
        detected(rows)=vpDecoded.hardPhysicalBins(rows);
        estimated(rows)=vp.estimatedCfoBins(rows);
        hard(:,:,block)=vpDecoded.hardDataBits(:,:,block);
        soft(:,:,block)=vpDecoded.softDataBits(:,:,block);
    else
        detected(rows)=plain.hardPhysicalBins(rows);
        estimated(rows)=plainTracker.predictedCfoBins(rows);
        hard(:,:,block)=plain.hardDataBits(:,:,block);
        soft(:,:,block)=plain.softDataBits(:,:,block);
    end
end
result=vp;
result.algorithmVersion='Stage55-B-cross-anchored-dual-block-v21';
result.detectedPhysicalBins=detected;
result.estimatedCfoBins=estimated;
result.hardDecodedDataBits=hard;
result.softDecodedDataBits=soft;
result.blockVpBranch=blockChoice;
result.blockBranchScore=blockScore;
result.virtualPilotAccepted=vp.tracker.pilotAccepted;
result.usesPayloadTruth=false;
result.usesOrbitTruth=false;
result.fftCount=vp.fftCount+c.payloadSymbolCount;
end
