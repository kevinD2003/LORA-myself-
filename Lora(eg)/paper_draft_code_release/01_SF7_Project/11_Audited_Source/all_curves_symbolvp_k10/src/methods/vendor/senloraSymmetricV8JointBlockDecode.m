function result = senloraSymmetricV8JointBlockDecode( ...
        observation,common,config,plan)
%SENLORASYMMETRICV8JOINTBLOCKDECODE Causal joint block CFO/Hamming ML.

c = config.parent;
layout = observation.layout;
if ~isempty(layout.midambleRows) || ...
        layout.physicalSymbolCount~=plan.nativePhysicalSymbolCount
    error('EXP5V8:NativeFrame','Joint-block validation requires V8 native frame.');
end
parameters = v4BCalibrationCandidates();
parameters = parameters(2);

pilots = observation.rxPhysical(layout.bootstrapRows,:);
joint = v4Stage55JointPreambleMlBootstrap(pilots,c, ...
    MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
predictedDrift = abs(joint.rateBinsPerSec)*plan.frameDurationSec;
rateGain = localSmoothStep(predictedDrift, ...
    plan.driftBlendStartBins,plan.driftBlendEndBins);
bootstrap = senloraSymmetricV8BlendBootstrap(common,joint,rateGain,c);
firstTracker = v4RollingTrackerPass( ...
    observation,bootstrap,c,parameters,false(c.payloadSymbolCount,1), ...
    InitialRateBinsPerSec=bootstrap.rateBinsPerSec);
firstDecoded = v4DecodePayload( ...
    firstTracker.compensatedData,c,common.noisePower);

searchBins = parameters.residualSearchBins( ...
    abs(parameters.residualSearchBins)<=parameters.innovationLimitBins);
nData = c.payloadSymbolCount;
compensatedData = complex(zeros(nData,c.samplesPerSymbol));
estimatedCfoBins = nan(nData,1);
selectedResidualBins = zeros(c.hammingBlockCount,1);
searchPeakRatio = ones(c.hammingBlockCount,1);
blockAccepted = false(c.hammingBlockCount,1);
blockHardSoftAgreement = false(c.hammingBlockCount,1);
blockMinimumMarginRatio = zeros(c.hammingBlockCount,1);
blockMinimumPeakRatio = zeros(c.hammingBlockCount,1);

historyTime = zeros(0,1);
historyCfo = zeros(0,1);
historyPeak = zeros(0,1);
correctionPhaseState = 0;

for block = 1:c.hammingBlockCount
    rows = (block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    blockCenterTime = mean(layout.physicalCenterTimeSec(layout.dataRows(rows)));
    [priorCfo,priorRate] = localPredictCorrection( ...
        historyTime,historyCfo,historyPeak,blockCenterTime,c,parameters);
    correctionReferenceTime = blockCenterTime;
    correctionCfoAtReference = priorCfo;
    correctionRate = priorRate;

    candidateSamples = cell(numel(searchBins),1);
    candidateDecoded = cell(numel(searchBins),1);
    candidateEndPhase = zeros(numel(searchBins),1);
    objective = zeros(numel(searchBins),1);
    for candidate = 1:numel(searchBins)
        delta = searchBins(candidate);
        phaseState = correctionPhaseState;
        samples = complex(zeros(c.hammingCodewordLength,c.samplesPerSymbol));
        for local = 1:c.hammingCodewordLength
            data = rows(local);
            time = layout.physicalCenterTimeSec(layout.dataRows(data));
            correctionCenter = correctionCfoAtReference+ ...
                correctionRate*(time-correctionReferenceTime)+delta;
            phaseStart = angle(exp(1i*( ...
                firstTracker.predictedPhaseRad(data)+phaseState)));
            samples(local,:) = v4CompensateSymbol( ...
                observation.rxPhysical(layout.dataRows(data),:), ...
                phaseStart,firstTracker.predictedCfoBins(data)+ ...
                correctionCenter,bootstrap.rateBinsPerSec+correctionRate,c);
            phaseState = angle(exp(1i*(phaseState+2*pi*correctionCenter)));
        end
        decoded = senloraSymmetricV8BlockLikelihood( ...
            samples,c,common.noisePower);
        candidateSamples{candidate} = samples;
        candidateDecoded{candidate} = decoded;
        candidateEndPhase(candidate) = phaseState;
        objective(candidate) = decoded.objective;
    end

    [orderedObjective,order] = sort(objective,'descend');
    selected = order(1);
    selectedDelta = searchBins(selected);
    chosen = candidateDecoded{selected};
    compensatedData(rows,:) = candidateSamples{selected};
    correctionPhaseState = candidateEndPhase(selected);
    selectedResidualBins(block) = selectedDelta;
    if numel(orderedObjective)>1
        normalizedMargin = (orderedObjective(1)-orderedObjective(2))/ ...
            (c.hammingCodewordLength*c.effectiveDataSf);
        searchPeakRatio(block) = exp(min(50,max(0,normalizedMargin)));
    else
        searchPeakRatio(block) = Inf;
    end
    blockHardSoftAgreement(block) = chosen.hardSoftAgreement;
    blockMinimumPeakRatio(block) = min(chosen.decisionPeakRatio);
    marginScale = max(mean(abs(chosen.bestCodewordScore)),eps);
    blockMinimumMarginRatio(block) = min(chosen.codewordMargin)/marginScale;
    blockAccepted(block) = chosen.hardSoftAgreement && ...
        blockMinimumPeakRatio(block)>=parameters.decisionPeakRatioThreshold && ...
        blockMinimumMarginRatio(block)>=parameters.softHammingMarginRatio && ...
        searchPeakRatio(block)>=parameters.residualPeakRatioThreshold;

    for local = 1:c.hammingCodewordLength
        data = rows(local);
        time = layout.physicalCenterTimeSec(layout.dataRows(data));
        correctionCenter = correctionCfoAtReference+ ...
            correctionRate*(time-correctionReferenceTime)+selectedDelta;
        estimatedCfoBins(data) = ...
            firstTracker.predictedCfoBins(data)+correctionCenter;
    end

    if blockAccepted(block) && block<c.hammingBlockCount
        measuredCfo = correctionCfoAtReference+selectedDelta;
        historyTime(end+1,1) = blockCenterTime; %#ok<AGROW>
        historyCfo(end+1,1) = measuredCfo; %#ok<AGROW>
        historyPeak(end+1,1) = searchPeakRatio(block); %#ok<AGROW>
        if numel(historyTime)>c.virtualPilotHistoryLength
            historyTime(1) = [];
            historyCfo(1) = [];
            historyPeak(1) = [];
        end
    end
end

finalDecoded = v4DecodePayload(compensatedData,c,common.noisePower);
result = struct( ...
    'methodName','SenLoRa-V8-Joint-Block-CFO-Hamming-ML', ...
    'methodId','senlora-v8-joint-block-validation', ...
    'algorithmVersion','SenLoRa-V8-joint-block-validation-v1', ...
    'detectedPhysicalBins',finalDecoded.hardPhysicalBins, ...
    'hardDecodedDataBits',finalDecoded.hardDataBits, ...
    'softDecodedDataBits',finalDecoded.softDataBits, ...
    'estimatedCfoBins',estimatedCfoBins, ...
    'firstPassDetectedPhysicalBins',firstDecoded.hardPhysicalBins, ...
    'firstPassEstimatedCfoBins',firstTracker.predictedCfoBins, ...
    'selectedResidualBins',selectedResidualBins, ...
    'searchPeakRatio',searchPeakRatio, ...
    'blockAccepted',blockAccepted, ...
    'blockHardSoftAgreement',blockHardSoftAgreement, ...
    'blockMinimumMarginRatio',blockMinimumMarginRatio, ...
    'blockMinimumPeakRatio',blockMinimumPeakRatio, ...
    'acceptedVirtualPilots',sum(blockAccepted(1:end-1))* ...
        c.hammingCodewordLength, ...
    'rateGain',rateGain,'jointPreambleEstimate',joint, ...
    'bootstrap',bootstrap,'firstPassTracker',firstTracker, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false, ...
    'usesCaseIdentity',false,'usesSnrInput',false, ...
    'usesTargetSer',false,'usesExplicitMidambles',false);
end

function [center,rate] = localPredictCorrection( ...
        historyTime,historyCfo,historyPeak,targetTime,c,parameters)
if isempty(historyTime)
    center = 0;
    rate = 0;
    return
end
x = historyTime-targetTime;
ageSymbols = max(0,(targetTime-historyTime)/c.symbolDurationSec);
weight = parameters.historyDecay.^ageSymbols.*min(3,max(1,historyPeak));
rate = 0;
if numel(historyTime)>=2
    information = sum((historyTime-mean(historyTime)).^2);
    rateStd = parameters.virtualPilotCfoStdBins/sqrt(max(information,eps));
    if rateStd<=parameters.virtualPilotRateStdLimitBinsPerSec
        design = [ones(size(x)),x];
        beta = localWeightedFit(design,historyCfo,weight);
        for iteration = 1:2
            residual = historyCfo-design*beta;
            robust = min(1,parameters.huberThresholdBins./ ...
                max(abs(residual),eps));
            beta = localWeightedFit(design,historyCfo,weight.*robust);
        end
        center = beta(1);
        rate = min(parameters.rateDeviationLimitBinsPerSec,max( ...
            -parameters.rateDeviationLimitBinsPerSec,beta(2)));
        return
    end
end
center = sum(weight.*historyCfo)/sum(weight);
end

function beta = localWeightedFit(design,response,weight)
sqrtWeight = sqrt(max(weight,eps));
beta = (design.*sqrtWeight)\(response.*sqrtWeight);
end

function value = localSmoothStep(x,lower,upper)
u = min(1,max(0,(x-lower)/(upper-lower)));
value = u*u*(3-2*u);
end
