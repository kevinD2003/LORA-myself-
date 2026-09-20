function result=v4Stage55CausalBlockBankDecodeV16(observation,bootstrap,c,p,options)
%V4STAGE55CAUSALBLOCKBANKDECODEV16 Causal block-local recovery bank.
% Each block is selected using only that block and earlier receiver state.

arguments
    observation (1,1) struct
    bootstrap (1,1) struct
    c (1,1) struct
    p (1,1) struct
    options.CrossFrameRateBinsPerSec (1,1) double=NaN
    options.CrossFrameHistoryCount (1,1) double=0
end

central=v4Stage55Decode(observation,bootstrap,c,p, ...
    CrossFrameRateBinsPerSec=options.CrossFrameRateBinsPerSec, ...
    CrossFrameHistoryCount=options.CrossFrameHistoryCount);
centralDecoded=v4DecodePayload(central.tracker.compensatedData,c,bootstrap.noisePower);
[centralHardScore,centralSoftScore,centralHardMetric]= ...
    localBlockScores(centralDecoded,c);
blockTriggered=centralHardMetric>0;
for block=1:c.hammingBlockCount
    rows=(block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    blockTriggered(block)=blockTriggered(block)||any( ...
        centralDecoded.confidenceReencodedPhysicalBins(rows)~= ...
        centralDecoded.hardPhysicalBins(rows));
end

result=central;
result.algorithmVersion='Stage55-B-causal-block-code-likelihood-bank-v16';
result.hardDecodedDataBits=centralDecoded.hardDataBits;
result.softDecodedDataBits=centralDecoded.softDataBits;
result.bitBankTriggered=any(blockTriggered);
result.blockTriggered=blockTriggered;
result.finalHardHypothesis=zeros(c.hammingBlockCount,2);
result.finalMlHypothesis=zeros(c.hammingBlockCount,2);
result.finalSymbolHypothesis=zeros(c.hammingBlockCount,2);
result.finalHardMetric=centralHardMetric;
result.finalHardScore=centralHardScore;
result.finalMlScore=centralSoftScore;
result.fftCount=central.fftCount+c.payloadSymbolCount;
if ~any(blockTriggered)
    return
end

cfoOffsets=-3:3;
rateOffsets=-4:2:4;
branchCount=1+numel(cfoOffsets)*numel(rateOffsets);
detectedBank=zeros(c.payloadSymbolCount,branchCount);
estimatedBank=zeros(c.payloadSymbolCount,branchCount);
acceptedBank=false(c.payloadSymbolCount,branchCount);
appliedBank=nan(c.payloadSymbolCount,branchCount);
availabilityBank=nan(c.payloadSymbolCount,branchCount);
activeBank=zeros(c.payloadSymbolCount,branchCount);
phaseBank=false(c.payloadSymbolCount,branchCount);
hardBank=false(c.effectiveDataSf,4,c.hammingBlockCount,branchCount);
softBank=false(c.effectiveDataSf,4,c.hammingBlockCount,branchCount);
hardScore=-inf(c.hammingBlockCount,branchCount);
softScore=-inf(c.hammingBlockCount,branchCount);
hardMetric=inf(c.hammingBlockCount,branchCount);
hypothesis=zeros(branchCount,2);

detectedBank(:,1)=centralDecoded.hardPhysicalBins;
estimatedBank(:,1)=central.tracker.predictedCfoBins;
acceptedBank(:,1)=central.virtualPilotAccepted;
appliedBank(:,1)=central.pilotFirstEffectivePhysicalRow;
availabilityBank(:,1)=central.pilotAvailabilityPhysicalRow;
activeBank(:,1)=central.activeHistoryCount;
phaseBank(:,1)=central.phasePairUsed;
hardBank(:,:,:,1)=centralDecoded.hardDataBits;
softBank(:,:,:,1)=centralDecoded.softDataBits;
hardScore(:,1)=centralHardScore;
softScore(:,1)=centralSoftScore;
hardMetric(:,1)=centralHardMetric;

branchIndex=1;
for co=cfoOffsets
    for ro=rateOffsets
        branchIndex=branchIndex+1;
        hypothesis(branchIndex,:)=[co ro];
        b=bootstrap;
        b.epsilonHatBins=bootstrap.epsilonHatBins+co;
        b.cfoBins=bootstrap.cfoBins+co;
        tracker=v4RollingTrackerPass(observation,b,c,p, ...
            false(c.payloadSymbolCount,1), ...
            InitialRateBinsPerSec=options.CrossFrameRateBinsPerSec+ro);
        d=v4DecodePayload(tracker.compensatedData,c,bootstrap.noisePower);
        [hs,ss,hm]=localBlockScores(d,c);
        detectedBank(:,branchIndex)=d.hardPhysicalBins;
        estimatedBank(:,branchIndex)=tracker.predictedCfoBins;
        availabilityBank(:,branchIndex)=tracker.pilotAvailabilityPhysicalRow;
        activeBank(:,branchIndex)=tracker.activeHistoryCount;
        hardBank(:,:,:,branchIndex)=d.hardDataBits;
        softBank(:,:,:,branchIndex)=d.softDataBits;
        hardScore(:,branchIndex)=hs;
        softScore(:,branchIndex)=ss;
        hardMetric(:,branchIndex)=hm;
        result.fftCount=result.fftCount+2*c.payloadSymbolCount;
        clear tracker d b
    end
end

for block=1:c.hammingBlockCount
    if ~blockTriggered(block)
        continue
    end
    hardBranch=localSelectBranch(hardScore(block,:),hardMetric(block,:),hypothesis);
    mlBranch=localSelectBranch(softScore(block,:),hardMetric(block,:),hypothesis);
    symbolBranch=mlBranch;
    rows=(block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    result.detectedPhysicalBins(rows)=detectedBank(rows,symbolBranch);
    result.estimatedCfoBins(rows)=estimatedBank(rows,symbolBranch);
    result.virtualPilotAccepted(rows)=acceptedBank(rows,symbolBranch);
    result.pilotFirstEffectivePhysicalRow(rows)=appliedBank(rows,symbolBranch);
    result.pilotAvailabilityPhysicalRow(rows)=availabilityBank(rows,symbolBranch);
    result.activeHistoryCount(rows)=activeBank(rows,symbolBranch);
    result.phasePairUsed(rows)=phaseBank(rows,symbolBranch);
    result.hardDecodedDataBits(:,:,block)=hardBank(:,:,block,hardBranch);
    result.softDecodedDataBits(:,:,block)=softBank(:,:,block,mlBranch);
    result.finalHardHypothesis(block,:)=hypothesis(hardBranch,:);
    result.finalMlHypothesis(block,:)=hypothesis(mlBranch,:);
    result.finalSymbolHypothesis(block,:)=hypothesis(symbolBranch,:);
    result.finalHardMetric(block)=hardMetric(block,hardBranch);
    result.finalHardScore(block)=hardScore(block,hardBranch);
    result.finalMlScore(block)=softScore(block,mlBranch);
end
result.bankHypotheses=hypothesis;
end

function index=localSelectBranch(score,hardMetric,hypothesis)
best=max(score);
tolerance=1e-10*max(1,abs(best));
candidates=find(score>=best-tolerance);
if numel(candidates)>1
    metric=hardMetric(candidates);
    candidates=candidates(metric==min(metric));
end
if numel(candidates)>1
    normValue=abs(hypothesis(candidates,1))+abs(hypothesis(candidates,2))/2;
    candidates=candidates(normValue==min(normValue));
end
index=candidates(1);
end

function [hardScore,softScore,hardMetric]=localBlockScores(d,c)
hardScore=zeros(c.hammingBlockCount,1);
softScore=zeros(c.hammingBlockCount,1);
hardMetric=zeros(c.hammingBlockCount,1);
table=v4Hamming74Table();
for block=1:c.hammingBlockCount
    rows=(block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    hardPhysical=localEncodeDataBits(d.hardDataBits(:,:,block),c);
    for symbol=1:c.hammingCodewordLength
        hardScore(block)=hardScore(block)+ ...
            d.symbolLogProbability(rows(symbol),hardPhysical(symbol)+1);
        softScore(block)=softScore(block)+d.symbolLogProbability( ...
            rows(symbol),d.softReencodedPhysicalBins(rows(symbol))+1);
    end
    gray=double(v4GrayEncode(uint32(d.hardPhysicalBins(rows))));
    code=v4DiagonalDeinterleave(gray,c);
    for row=1:c.effectiveDataSf
        hardMetric(block)=hardMetric(block)+min(sum(table~=code(row,:),2));
    end
end
end

function physical=localEncodeDataBits(dataBits,c)
data=double(dataBits);
parity=mod([data(:,1)+data(:,2)+data(:,4), ...
    data(:,1)+data(:,3)+data(:,4), ...
    data(:,2)+data(:,3)+data(:,4)],2);
gray=v4DiagonalInterleave([data parity],c);
physical=double(v4GrayDecode(uint32(gray)));
end
