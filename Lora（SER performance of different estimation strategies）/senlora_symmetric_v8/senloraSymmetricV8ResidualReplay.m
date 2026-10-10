function tracker = senloraSymmetricV8ResidualReplay( ...
        observation,firstTracker,firstDecoded,candidateMask,bootstrap,c,parameters)
%SENLORASYMMETRICV8RESIDUALREPLAY Causal blockwise residual CFO/rate replay.

arguments
    observation (1,1) struct
    firstTracker (1,1) struct
    firstDecoded (1,1) struct
    candidateMask (:,1) logical
    bootstrap (1,1) struct
    c (1,1) struct
    parameters (1,1) struct
end

layout = observation.layout;
nData = c.payloadSymbolCount;
if numel(candidateMask)~=nData
    error('EXP5V8:ResidualCandidateShape', ...
        'Candidate mask must match the payload symbol count.');
end

residualCfoBins = nan(nData,1);
residualPeakRatio = nan(nData,1);
residualEligible = false(nData,1);
candidatePhysicalBins = firstDecoded.softReencodedPhysicalBins(:);
for data = find(candidateMask(:)).'
    residual = v4PhaseRotationEstimate( ...
        firstTracker.compensatedData(data,:),candidatePhysicalBins(data), ...
        c,parameters.residualSearchBins);
    qualityOk = residual.peakRatio >= ...
        parameters.residualPeakRatioThreshold && ...
        firstTracker.decisionPeakRatio(data) >= ...
        parameters.decisionPeakRatioThreshold && ...
        ~residual.peakAtBoundary;
    innovationOk = abs(residual.offsetBins) <= ...
        parameters.innovationLimitBins;
    if qualityOk && innovationOk
        residualCfoBins(data) = residual.offsetBins;
        residualPeakRatio(data) = residual.peakRatio;
        residualEligible(data) = true;
    end
end

compensatedData = complex(zeros(nData,c.samplesPerSymbol));
predictedCfoBins = nan(nData,1);
predictedPhaseRad = nan(nData,1);
correctionCfoBins = zeros(nData,1);
correctionRateBinsPerSec = zeros(nData,1);
correctionPhaseRad = zeros(nData,1);
rateObservable = false(nData,1);
pilotAccepted = false(nData,1);
pilotAppliedAtData = nan(nData,1);

historyData = zeros(0,1);
correctionPhaseState = 0;
correctionReferenceTime = layout.physicalCenterTimeSec(layout.dataRows(1));
correctionCfoAtReference = 0;
correctionRate = 0;

for block = 1:c.hammingBlockCount
    rows = (block-1)*c.hammingCodewordLength+(1:c.hammingCodewordLength);
    if block > 1
        previous = rows-c.hammingCodewordLength;
        admitted = previous(residualEligible(previous));
        for data = admitted(:).'
            historyData(end+1,1) = data; %#ok<AGROW>
            if numel(historyData) > c.virtualPilotHistoryLength
                historyData(1) = [];
            end
            pilotAccepted(data) = true;
            pilotAppliedAtData(data) = rows(1);
        end
        targetTime = layout.physicalCenterTimeSec(layout.dataRows(rows(1)));
        [correctionCfoAtReference,correctionRate,isRateObservable] = ...
            localResidualFit(historyData,residualCfoBins, ...
            residualPeakRatio,targetTime,layout,c,parameters);
        correctionReferenceTime = targetTime;
    else
        isRateObservable = false;
    end

    for data = rows
        targetTime = layout.physicalCenterTimeSec(layout.dataRows(data));
        correctionCenter = correctionCfoAtReference+ ...
            correctionRate*(targetTime-correctionReferenceTime);
        phaseStart = angle(exp(1i*( ...
            firstTracker.predictedPhaseRad(data)+correctionPhaseState)));
        totalCfo = firstTracker.predictedCfoBins(data)+correctionCenter;
        totalRate = bootstrap.rateBinsPerSec+correctionRate;
        compensatedData(data,:) = v4CompensateSymbol( ...
            observation.rxPhysical(layout.dataRows(data),:), ...
            phaseStart,totalCfo,totalRate,c);
        predictedCfoBins(data) = totalCfo;
        predictedPhaseRad(data) = phaseStart;
        correctionCfoBins(data) = correctionCenter;
        correctionRateBinsPerSec(data) = correctionRate;
        correctionPhaseRad(data) = correctionPhaseState;
        rateObservable(data) = isRateObservable;
        correctionPhaseState = angle(exp(1i*( ...
            correctionPhaseState+2*pi*correctionCenter)));
    end
end

tracker = struct('compensatedData',compensatedData, ...
    'predictedCfoBins',predictedCfoBins, ...
    'predictedPhaseRad',predictedPhaseRad, ...
    'correctionCfoBins',correctionCfoBins, ...
    'correctionRateBinsPerSec',correctionRateBinsPerSec, ...
    'correctionPhaseRad',correctionPhaseRad, ...
    'rateObservable',rateObservable, ...
    'pilotAccepted',pilotAccepted, ...
    'pilotAppliedAtData',pilotAppliedAtData, ...
    'candidatePhysicalBins',candidatePhysicalBins, ...
    'residualCfoBins',residualCfoBins, ...
    'residualPeakRatio',residualPeakRatio, ...
    'residualEligible',residualEligible, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end

function [center,rate,rateObservable] = localResidualFit( ...
        historyData,residualCfo,residualPeak,targetTime,layout,c,parameters)
if isempty(historyData)
    center = 0;
    rate = 0;
    rateObservable = false;
    return
end

time = layout.physicalCenterTimeSec(layout.dataRows(historyData));
cfo = residualCfo(historyData);
peak = residualPeak(historyData);
ageSymbols = max(0,(targetTime-time)/c.symbolDurationSec);
weight = parameters.historyDecay.^ageSymbols.*min(3,max(1,peak));

rateObservable = false;
rate = 0;
historyBlock = ceil(historyData/c.hammingCodewordLength);
if numel(unique(historyBlock)) >= 2
    centeredTime = time-mean(time);
    information = sum((centeredTime-mean(centeredTime)).^2);
    rateStd = parameters.virtualPilotCfoStdBins/ ...
        sqrt(max(information,eps));
    rateObservable = rateStd <= ...
        parameters.virtualPilotRateStdLimitBinsPerSec;
end

if rateObservable
    x = time-targetTime;
    design = [ones(size(x)),x];
    beta = localWeightedFit(design,cfo,weight);
    for iteration = 1:2
        fitResidual = cfo-design*beta;
        robust = min(1,parameters.huberThresholdBins./ ...
            max(abs(fitResidual),eps));
        beta = localWeightedFit(design,cfo,weight.*robust);
    end
    center = beta(1);
    rate = min(parameters.rateDeviationLimitBinsPerSec,max( ...
        -parameters.rateDeviationLimitBinsPerSec,beta(2)));
else
    center = sum(weight.*cfo)/sum(weight);
end
center = min(parameters.innovationLimitBins,max( ...
    -parameters.innovationLimitBins,center));
end

function beta = localWeightedFit(design,response,weight)
sqrtWeight = sqrt(max(weight,eps));
beta = (design.*sqrtWeight)\(response.*sqrtWeight);
end
