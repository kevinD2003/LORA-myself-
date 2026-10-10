function result = senloraSymmetricV3Decode(observation,common,config,plan)
%SENLORASYMMETRICV3DECODE Parent-safe, Hamming-block consensus receiver.

c = config.parent;
v2 = senloraSymmetricV2Decode(observation,common,config,plan);
parent = exp1Stage55Decode(observation,common,config,true);
v2Decision = v2.decision;
v2Monitor = v2.monitor;
parentStatic = parent.modeEvidence.staticSelected;
parentStaticProtected = parentStatic && ...
    v2.decision.staticScorePerSymbol>=plan.staticScoreFloorPerSymbol;
v2Detected = v2.detectedPhysicalBins(:);

if parentStaticProtected
    result = v2;
    result.detectedPhysicalBins = parent.detectedPhysicalBins;
    result.hardDecodedDataBits = parent.hardDecodedDataBits;
    result.softDecodedDataBits = parent.softDecodedDataBits;
    result.estimatedCfoBins = parent.estimatedCfoBins;
    result.virtualPilotAccepted = parent.virtualPilotAccepted;
    blockBranches = ones(c.hammingBlockCount,1,'uint8');
    blockCosts = nan(c.hammingBlockCount,3);
    blockScores = nan(c.hammingBlockCount,3);
    selectedName = 'frozen-parent-static';
    selectedBranch = uint8(1);
    hasSingleSelectedBranch = true;
    parentExactByConstruction = true;
else
    baseDecoded = v4DecodePayload( ...
        v2.baseDynamicHypothesis.tracker.compensatedData,c,common.noisePower);
    decoded = {baseDecoded,v2.rateBank.selectedDecoded, ...
        v2.loboHypothesis.decoded};
    estimatedCfo = {v2.baseDynamicHypothesis.estimatedCfoBins(:), ...
        v2.rateBank.selectedTracker.predictedCfoBins(:), ...
        v2.loboHypothesis.estimatedCfoBins(:)};
    accepted = {logical(v2.baseDynamicHypothesis.virtualPilotAccepted(:)), ...
        false(c.payloadSymbolCount,1), ...
        logical(v2.loboHypothesis.acceptedMeasurementMask(:))};
    defaultBranch = v2.decision.selectedBranch-1;
    if defaultBranch<1 || defaultBranch>3
        [~,defaultBranch] = max(v2.decision.branchScores(2:4));
    end
    [hardBins,hardBits,softBits,selectedCfo,selectedAccepted, ...
        blockBranches,blockCosts,blockScores] = ...
        localBlockMedoid(decoded,estimatedCfo,accepted,defaultBranch,c);
    result = v2;
    result.detectedPhysicalBins = hardBins;
    result.hardDecodedDataBits = hardBits;
    result.softDecodedDataBits = softBits;
    result.estimatedCfoBins = selectedCfo;
    result.virtualPilotAccepted = selectedAccepted;
    selectedName = 'dynamic-hamming-block-medoid';
    selectedBranch = uint8(0);
    hasSingleSelectedBranch = false;
    parentExactByConstruction = false;
end

result.methodName = 'SenLoRa-Symmetric-Parent-Safe-Medoid';
result.methodId = 'senlora-symmetric-v3';
result.algorithmVersion = plan.receiverVersion;
result.v2CandidateDetectedPhysicalBins = v2Detected;
symbolBranches = repelem(blockBranches,c.hammingCodewordLength);
symbolBlockScores = repelem(blockScores,c.hammingCodewordLength,1);
blockIndex = repelem((1:c.hammingBlockCount).',c.hammingCodewordLength);
monitor = v2Monitor;
monitor.appliedCompensationBins = result.estimatedCfoBins(:);
monitor.selectedBranch = symbolBranches;
monitor.acceptedMeasurement = logical(result.virtualPilotAccepted(:));
monitor.hammingBlockIndex = blockIndex;
monitor.branchScores = symbolBlockScores;
monitor.branchScoreBranchIds = uint8([2 3 4]);
monitor.v2SelectedBranch = repmat( ...
    uint8(v2Decision.selectedBranch),c.payloadSymbolCount,1);
monitor.v2BranchScores = v2Monitor.branchScores;
monitor.selectionMode = repmat(string(selectedName),c.payloadSymbolCount,1);
result.monitor = monitor;
result.decision = struct('selectedBranch',selectedBranch, ...
    'hasSingleSelectedBranch',hasSingleSelectedBranch, ...
    'selectedBranchName',selectedName, ...
    'blockSelectedBranches',blockBranches, ...
    'branchScores',blockScores, ...
    'branchScoreBranchIds',uint8([2 3 4]), ...
    'blockConsensusCosts',blockCosts, ...
    'blockConsensusScores',blockScores, ...
    'v2SelectedBranch',uint8(v2Decision.selectedBranch), ...
    'v2BranchScores',v2Decision.branchScores, ...
    'parentStaticSelected',parentStatic, ...
    'parentStaticProtected',parentStaticProtected, ...
    'parentExactByConstruction',parentExactByConstruction, ...
    'hammingBlockLocalSelection',~parentStaticProtected, ...
    'wholePayloadReplay',parentStaticProtected, ...
    'leaveOneBlockOut',v2.loboHypothesis.leaveOneBlockOut, ...
    'selfBlockUsedForFit',v2.loboHypothesis.selfBlockUsedForFit, ...
    'usesOrbitTruth',false,'usesTargetSer',false);
result.frozenParentHypothesis = parent;
result.usesPayloadTruth = false;
result.usesOrbitTruth = false;
result.usesCaseIdentity = false;
result.usesSnrInput = false;
result.usesTargetSer = false;
end

function [hardBins,hardBits,softBits,estimatedCfo,accepted, ...
        selectedBranches,blockCosts,blockScores] = ...
        localBlockMedoid(decoded,cfo,admission,defaultBranch,c)
branchCount = numel(decoded);
hardBins = zeros(c.payloadSymbolCount,1);
hardBits = zeros(size(decoded{1}.hardDataBits));
softBits = zeros(size(decoded{1}.softDataBits));
estimatedCfo = nan(c.payloadSymbolCount,1);
accepted = false(c.payloadSymbolCount,1);
selectedBranches = zeros(c.hammingBlockCount,1,'uint8');
blockCosts = zeros(c.hammingBlockCount,branchCount);
blockScores = zeros(c.hammingBlockCount,branchCount);
for block = 1:c.hammingBlockCount
    rows = (block-1)*c.hammingCodewordLength+ ...
        (1:c.hammingCodewordLength);
    for branch = 1:branchCount
        for other = 1:branchCount
            if other~=branch
                blockCosts(block,branch) = blockCosts(block,branch)+sum( ...
                    decoded{branch}.hardPhysicalBins(rows)~= ...
                    decoded{other}.hardPhysicalBins(rows));
            end
        end
        blockScores(block,branch) = localBlockCodeScore( ...
            decoded{branch},rows);
    end
    minimumCost = min(blockCosts(block,:));
    candidates = find(blockCosts(block,:)==minimumCost);
    if numel(candidates)>1
        [~,best] = max(blockScores(block,candidates));
        selected = candidates(best);
    else
        selected = candidates(1);
    end
    if blockScores(block,selected)<blockScores(block,defaultBranch)
        selected = defaultBranch;
    end
    selectedBranches(block) = uint8(selected+1);
    hardBins(rows) = decoded{selected}.hardPhysicalBins(rows);
    hardBits(:,:,block) = decoded{selected}.hardDataBits(:,:,block);
    softBits(:,:,block) = decoded{selected}.softDataBits(:,:,block);
    estimatedCfo(rows) = cfo{selected}(rows);
    accepted(rows) = admission{selected}(rows);
end
end

function score = localBlockCodeScore(decoded,rows)
labels = decoded.confidenceReencodedPhysicalBins(rows)+1;
indices = sub2ind(size(decoded.symbolLogProbability),rows(:),labels(:));
score = sum(decoded.symbolLogProbability(indices));
end
