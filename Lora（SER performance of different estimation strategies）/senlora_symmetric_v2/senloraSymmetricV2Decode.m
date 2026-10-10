function result = senloraSymmetricV2Decode(observation,common,config,plan)
%SENLORASYMMETRICV2DECODE Leave-one-Hamming-block-out packet replay.

c = config.parent;
pilots = observation.rxPhysical(1:c.bootstrapPilotCount,:);
parameters = v4BCalibrationCandidates();
parameters = parameters(2);
joint = v4Stage55JointPreambleMlBootstrap(pilots,c, ...
    MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
bootstrap = v4Stage55BootstrapFromJointPreambleMl(common,joint,c);
static = reviewStaticHypothesis(observation,common,c);
rateBank = localRateBank(observation,bootstrap,joint.rateBinsPerSec, ...
    c,parameters,plan);
selectedRate = joint.rateBinsPerSec+rateBank.selectedOffsetBinsPerSec;
base = v4Stage55Decode(observation,bootstrap,c,parameters, ...
    CrossFrameRateBinsPerSec=joint.rateBinsPerSec, ...
    CrossFrameHistoryCount=1);
baseDecoded = v4DecodePayload(base.tracker.compensatedData,c,common.noisePower);
lobo = localLeaveOneBlockReplay(observation,bootstrap, ...
    rateBank.selectedDecoded,rateBank.selectedTracker.compensatedData, ...
    rateBank.selectedTracker.predictedCfoBins(:), ...
    c,common.noisePower,plan);

scores = [localCodeScore(static.decoded,c), ...
    localCodeScore(baseDecoded,c), ...
    localCodeScore(rateBank.selectedDecoded,c), ...
    localCodeScore(lobo.decoded,c)];
frameDrift = abs(joint.rateBinsPerSec)*plan.frameDurationSec;
staticScorePerSymbol = scores(1)/c.payloadSymbolCount;
staticProtected = frameDrift<=plan.lowDriftDefaultBins && ...
    staticScorePerSymbol>=plan.staticScoreFloorPerSymbol;
if staticProtected
    defaultBranch = 1;
else
    defaultBranch = 2;
end
[bestScore,bestBranch] = max(scores);
minimumGain = plan.branchGainPerSymbol*c.payloadSymbolCount;
if staticProtected
    selectedBranch = 1;
elseif bestScore<scores(defaultBranch)+minimumGain
    selectedBranch = defaultBranch;
else
    selectedBranch = bestBranch;
end

switch selectedBranch
    case 1
        decoded = static.decoded;
        estimatedCfo = static.estimatedCfoBins(:);
        accepted = false(c.payloadSymbolCount,1);
        branchName = 'frozen-static';
    case 2
        decoded = baseDecoded;
        estimatedCfo = base.estimatedCfoBins(:);
        accepted = logical(base.virtualPilotAccepted(:));
        branchName = 'frozen-dynamic';
    case 3
        decoded = rateBank.selectedDecoded;
        estimatedCfo = rateBank.selectedTracker.predictedCfoBins(:);
        accepted = false(c.payloadSymbolCount,1);
        branchName = 'fine-rate-bank-no-VP';
    otherwise
        decoded = lobo.decoded;
        estimatedCfo = lobo.estimatedCfoBins;
        accepted = lobo.acceptedMeasurementMask;
        branchName = 'local-LOBO-quadratic-replay';
end

n = c.payloadSymbolCount;
layout = observation.layout;
monitor = struct('symbolIndex',(1:n).', ...
    'absoluteTimeSec',layout.physicalCenterTimeSec(layout.dataRows), ...
    'appliedCompensationBins',estimatedCfo, ...
    'selectedBranch',repmat(selectedBranch,n,1), ...
    'acceptedMeasurement',accepted, ...
    'loboMeasurementMask',lobo.acceptedMeasurementMask, ...
    'loboResidualBins',lobo.residualBins, ...
    'loboFitCfoBins',lobo.estimatedCfoBins, ...
    'branchScores',repmat(scores,n,1));
decision = struct('selectedBranch',selectedBranch, ...
    'selectedBranchName',branchName,'branchScores',scores, ...
    'defaultBranch',defaultBranch,'frameDriftBins',frameDrift, ...
    'staticProtected',staticProtected, ...
    'staticScorePerSymbol',staticScorePerSymbol, ...
    'selectedRateBinsPerSec',selectedRate, ...
    'rateBankSelectedOffsetBinsPerSec', ...
        rateBank.selectedOffsetBinsPerSec, ...
    'minimumScoreGain',minimumGain,'wholePayloadReplay',true, ...
    'leaveOneBlockOut',lobo.leaveOneBlockOut, ...
    'selfBlockUsedForFit',lobo.selfBlockUsedForFit, ...
    'usesOrbitTruth',false,'usesTargetSer',false);
result = struct('methodName','SenLoRa-Symmetric-LOBO', ...
    'methodId','senlora-symmetric-v2','algorithmVersion', ...
        plan.receiverVersion,'detectedPhysicalBins',decoded.hardPhysicalBins, ...
    'hardDecodedDataBits',decoded.hardDataBits, ...
    'softDecodedDataBits',decoded.softDataBits, ...
    'estimatedCfoBins',estimatedCfo, ...
    'virtualPilotAccepted',accepted, ...
    'explicitMidambleAccepted',false(c.paperMidambleCount,1), ...
    'monitor',monitor,'decision',decision,'staticHypothesis',static, ...
    'baseDynamicHypothesis',base,'loboHypothesis',lobo, ...
    'jointPreambleEstimate',joint,'rateBank',rateBank, ...
    'usesPayloadTruth',false, ...
    'usesOrbitTruth',false,'usesCaseIdentity',false, ...
    'usesSnrInput',false,'usesTargetSer',false);
end

function bank = localRateBank(observation,bootstrap,jointRate,c,parameters,plan)
offsets = plan.rateBankOffsetsBinsPerSec(:);
scores = nan(numel(offsets),1);
trackers = cell(numel(offsets),1);
decodes = cell(numel(offsets),1);
for index = 1:numel(offsets)
    tracker = v4RollingTrackerPass(observation,bootstrap,c,parameters, ...
        false(c.payloadSymbolCount,1), ...
        InitialRateBinsPerSec=jointRate+offsets(index));
    decoded = v4DecodePayload( ...
        tracker.compensatedData,c,bootstrap.noisePower);
    scores(index) = localCodeScore(decoded,c);
    trackers{index} = tracker;
    decodes{index} = decoded;
end
bestScore = max(scores);
tolerance = 1e-10*max(1,abs(bestScore));
candidates = find(scores>=bestScore-tolerance);
if numel(candidates)>1
    [~,tie] = min(abs(offsets(candidates)));
    selected = candidates(tie);
else
    selected = candidates(1);
end
bank = struct('offsetsBinsPerSec',offsets,'codeScores',scores, ...
    'selectedIndex',selected, ...
    'selectedOffsetBinsPerSec',offsets(selected), ...
    'selectedTracker',trackers{selected}, ...
    'selectedDecoded',decodes{selected}, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end

function replay = localLeaveOneBlockReplay(observation,bootstrap,decoded, ...
        compensated,fitCfo,c,noisePower,plan)
layout = observation.layout;
dataTime = layout.physicalCenterTimeSec(layout.dataRows);
preambleTime = layout.physicalCenterTimeSec(layout.bootstrapRows);
history = repmat(struct(),plan.refinementIterations,1);
finalMask = false(c.payloadSymbolCount,1);
finalResidual = nan(c.payloadSymbolCount,1);
finalLabels = nan(c.payloadSymbolCount,1);
blockFitUsesSelf = false(c.hammingBlockCount,1);
for iteration = 1:plan.refinementIterations
    [mask,residualBins,peakRatio,measuredCfo,labels] = localMeasurements( ...
        compensated,decoded,fitCfo,c,plan);
    mask = localLimitPerBlock(mask,peakRatio, ...
        decoded.symbolCodewordMargin(:),c,plan);
    measuredCfo(~mask) = NaN;
    nextCompensated = complex(zeros(size(compensated)));
    nextFitCfo = nan(c.payloadSymbolCount,1);
    blockCoefficients = cell(c.hammingBlockCount,1);
    blockFitPayloadRows = cell(c.hammingBlockCount,1);
    for heldBlock = 1:c.hammingBlockCount
        heldRows = (heldBlock-1)*c.hammingCodewordLength+ ...
            (1:c.hammingCodewordLength);
        otherMask = mask;
        otherMask(heldRows) = false;
        otherRows = find(otherMask);
        targetTime = mean(dataTime(heldRows));
        time = [preambleTime(:);dataTime(otherMask)];
        cfoValues = [bootstrap.cfoBins(:);measuredCfo(otherMask)];
        quality = [ones(numel(preambleTime),1); ...
            min(4,max(1,peakRatio(otherMask)))];
        [~,nearest] = sort(abs(time-targetTime),'ascend');
        nearest = nearest(1:min(plan.localFitPointCount,numel(nearest)));
        payloadNearest = nearest(nearest>numel(preambleTime))- ...
            numel(preambleTime);
        selectedPayloadRows = otherRows(payloadNearest);
        beta = localRobustPolynomial( ...
            time(nearest),cfoValues(nearest),quality(nearest),plan);
        [blockCfo,blockRate] = localEvaluatePolynomial( ...
            beta,dataTime(heldRows));
        nextFitCfo(heldRows) = blockCfo;
        for offset = 1:numel(heldRows)
            data = heldRows(offset);
            row = layout.dataRows(data);
            nextCompensated(data,:) = v4CompensateSymbol( ...
                observation.rxPhysical(row,:),0, ...
                blockCfo(offset),blockRate(offset),c);
        end
        blockCoefficients{heldBlock} = beta;
        blockFitPayloadRows{heldBlock} = selectedPayloadRows;
        blockFitUsesSelf(heldBlock) = blockFitUsesSelf(heldBlock) || ...
            any(ismember(selectedPayloadRows,heldRows));
    end
    compensated = nextCompensated;
    fitCfo = nextFitCfo;
    decoded = v4DecodePayload(compensated,c,noisePower);
    history(iteration).acceptedCount = sum(mask);
    history(iteration).acceptedMask = mask;
    history(iteration).blockCoefficients = blockCoefficients;
    history(iteration).blockFitPayloadRows = blockFitPayloadRows;
    history(iteration).blockFitUsesSelf = blockFitUsesSelf;
    history(iteration).residualBins = residualBins;
    finalMask = mask;
    finalResidual = residualBins;
    finalLabels = labels;
end
if any(blockFitUsesSelf)
    error('EXP5V2:SelfBlockLeak','A held-out block entered its own CFO fit.');
end
replay = struct('decoded',decoded,'compensatedData',compensated, ...
    'estimatedCfoBins',fitCfo,'acceptedMeasurementMask',finalMask, ...
    'measurementLabels',finalLabels,'residualBins',finalResidual, ...
    'iterationHistory',history, ...
    'leaveOneBlockOut',true, ...
    'selfBlockUsedForFit',any(blockFitUsesSelf), ...
    'maximumMeasurementsPerBlock',plan.maximumMeasurementsPerBlock, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end

function [mask,residualBins,peakRatio,measuredCfo,labels] = ...
        localMeasurements(compensated,decoded,fitCfo,c,plan)
labels = decoded.confidenceReencodedPhysicalBins(:);
agreement = labels==decoded.hardPhysicalBins(:);
margin = decoded.symbolCodewordMargin(:);
mask = false(c.payloadSymbolCount,1);
residualBins = nan(c.payloadSymbolCount,1);
peakRatio = nan(c.payloadSymbolCount,1);
measuredCfo = nan(c.payloadSymbolCount,1);
for data = 1:c.payloadSymbolCount
    residual = v4PhaseRotationEstimate( ...
        compensated(data,:),labels(data),c,plan.residualCandidatesBins);
    residualBins(data) = residual.offsetBins;
    peakRatio(data) = residual.peakRatio;
    mask(data) = agreement(data) && ...
        margin(data)>=plan.minimumCodewordMargin && ...
        residual.peakRatio>=plan.residualPeakRatioMinimum && ...
        ~residual.peakAtBoundary && ...
        abs(residual.offsetBins)<=plan.residualInnovationLimitBins;
    if mask(data)
        measuredCfo(data) = fitCfo(data)+residual.offsetBins;
    end
end
end

function mask = localLimitPerBlock(mask,peakRatio,margin,c,plan)
for block = 1:c.hammingBlockCount
    rows = (block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    candidates = rows(mask(rows));
    if numel(candidates)>plan.maximumMeasurementsPerBlock
        quality = peakRatio(candidates).*max(margin(candidates),eps);
        [~,order] = sort(quality,'descend');
        rejected = candidates(order(plan.maximumMeasurementsPerBlock+1:end));
        mask(rejected) = false;
    end
end
end

function beta = localRobustPolynomial(time,cfo,weight,plan)
center = mean(time);
scale = max(max(abs(time-center)),eps);
x = (time-center)/scale;
design = ones(numel(x),plan.polynomialOrder+1);
for order = 1:plan.polynomialOrder
    design(:,order+1) = x.^order;
end
value = localWeightedFit(design,cfo,weight);
for iteration = 1:3
    residual = cfo-design*value;
    robust = min(1,plan.huberThresholdBins./max(abs(residual),eps));
    value = localWeightedFit(design,cfo,weight.*robust);
end
beta = struct('value',value,'centerTimeSec',center,'scaleTimeSec',scale);
end

function [cfo,rate] = localEvaluatePolynomial(beta,time)
x = (time-beta.centerTimeSec)/beta.scaleTimeSec;
cfo = beta.value(1)+beta.value(2)*x;
rate = repmat(beta.value(2)/beta.scaleTimeSec,size(time));
if numel(beta.value)>=3
    cfo = cfo+beta.value(3)*x.^2;
    rate = rate+2*beta.value(3)*x/beta.scaleTimeSec;
end
end

function beta = localWeightedFit(design,response,weight)
rootWeight = sqrt(max(weight,eps));
beta = (design.*rootWeight)\(response.*rootWeight);
end

function score = localCodeScore(decoded,c)
rows = (1:c.payloadSymbolCount).';
labels = decoded.confidenceReencodedPhysicalBins(:)+1;
indices = sub2ind(size(decoded.symbolLogProbability),rows,labels);
score = sum(decoded.symbolLogProbability(indices));
end
