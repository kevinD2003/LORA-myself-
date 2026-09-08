function tracker = v4RollingTrackerPass(observation,bootstrap,config,parameters,candidateMask,options)
%V4ROLLINGTRACKERPASS One causal replay with an eight-observation history.

arguments
    observation (1,1) struct
    bootstrap (1,1) struct
    config (1,1) struct
    parameters (1,1) struct
    candidateMask (:,1) logical
    options.InitialRateBinsPerSec (1,1) double = NaN
end

v4ValidateReceiverParameters(parameters);
layout = observation.layout;
nData = config.payloadSymbolCount;
historyTime = nan(config.virtualPilotHistoryLength,1);
historyCfo = nan(config.virtualPilotHistoryLength,1);
historyConfidence = ones(config.virtualPilotHistoryLength,1);
historyPeak = ones(config.virtualPilotHistoryLength,1);
historyCount = config.virtualPilotHistoryLength;
historyTime(:) = layout.physicalCenterTimeSec(layout.bootstrapRows);
historyCfo(:) = bootstrap.cfoBins;
nextSlot = 1;
availabilityRow = zeros(nData,1);
for block = 1:config.hammingBlockCount
    data = (block-1)*config.hammingCodewordLength+(1:config.hammingCodewordLength);
    availabilityRow(data) = min(layout.physicalSymbolCount+1, ...
        layout.dataRows(data(end))+1);
end

compensatedData = complex(zeros(nData,config.samplesPerSymbol));
hardPhysicalBins = nan(nData,1);
decisionPeakRatio = nan(nData,1);
predictedCfoBins = nan(nData,1);
predictedPhaseRad = nan(nData,1);
pilotAccepted = false(nData,1);
pilotAppliedAtPhysicalRow = nan(nData,1);
activeHistoryCount = zeros(nData,1);
phasePairUsed = false(nData,1);
vpRows = zeros(0,1);
vpCfo = zeros(0,1);
lastVp = struct('data',NaN,'measuredPhase',NaN,'predictedPhase',NaN);
[phaseState,bootstrapRateCfo] = v4BootstrapStateAtSymbol( ...
    bootstrap,config.bootstrapPilotCount,config); %#ok<ASGLU>
bootstrapRate = bootstrap.rateBinsPerSec;
if isfinite(options.InitialRateBinsPerSec)
    bootstrapRate = options.InitialRateBinsPerSec;
end
for row = config.bootstrapPilotCount+1:layout.physicalSymbolCount
    delayed = find(candidateMask & availabilityRow == row);
    latestCorrectionData = NaN;
    latestCorrection = 0;
    for data = delayed(:).'
        residual = v4PhaseRotationEstimate(compensatedData(data,:), ...
            hardPhysicalBins(data),config,parameters.residualSearchBins);
        innovationOk = abs(residual.offsetBins) <= parameters.innovationLimitBins;
        qualityOk = residual.peakRatio >= parameters.residualPeakRatioThreshold && ...
            decisionPeakRatio(data) >= parameters.decisionPeakRatioThreshold && ...
            ~residual.peakAtBoundary;
        if qualityOk && innovationOk
            rawSingle = predictedCfoBins(data)+residual.offsetBins;
            measured = predictedCfoBins(data)+parameters.singleSymbolInnovationGain* ...
                (rawSingle-predictedCfoBins(data));
            measuredPhase = predictedPhaseRad(data)+residual.phaseRad;
            if isfinite(lastVp.data)
                gap = layout.dataRows(data)-layout.dataRows(lastVp.data);
                measuredAverage = angle(exp(1i*(measuredPhase-lastVp.measuredPhase)))/ ...
                    (2*pi*gap);
                predictedAverage = angle(exp(1i*(predictedPhaseRad(data)- ...
                    lastVp.predictedPhase)))/(2*pi*gap);
                pairEndpoint = measuredAverage+0.5*bootstrapRate*gap*config.symbolDurationSec;
                if abs(measuredAverage-predictedAverage) <= ...
                        parameters.phasePairInnovationLimitBins && ...
                        abs(pairEndpoint-rawSingle) <= ...
                        parameters.phasePairAgreementLimitBins
                    measured = predictedCfoBins(data)+parameters.phasePairInnovationGain* ...
                        (pairEndpoint-predictedCfoBins(data));
                    phasePairUsed(data) = true;
                end
            end
            historyTime(nextSlot) = layout.physicalCenterTimeSec(layout.dataRows(data));
            historyCfo(nextSlot) = measured;
            historyConfidence(nextSlot) = 1;
            historyPeak(nextSlot) = residual.peakRatio;
            nextSlot = mod(nextSlot,config.virtualPilotHistoryLength)+1;
            vpRows(end+1,1) = layout.dataRows(data); %#ok<AGROW>
            vpCfo(end+1,1) = rawSingle; %#ok<AGROW>
            pilotAccepted(data) = true;
            pilotAppliedAtPhysicalRow(data) = row;
            lastVp = struct('data',data,'measuredPhase',measuredPhase, ...
                'predictedPhase',predictedPhaseRad(data));
            latestCorrectionData = data;
            age = row-layout.dataRows(data);
            latestCorrection = residual.phaseRad+2*pi*residual.offsetBins*age;
        end
    end
    if isfinite(latestCorrectionData)
        phaseState = angle(exp(1i*(phaseState+latestCorrection)));
    end
    targetTime = layout.physicalCenterTimeSec(row);
    [vpRate,vpRateStd] = localVpRate(vpRows,vpCfo,layout,config,parameters);
    rateObservable = isfinite(vpRate) && ...
        vpRateStd <= parameters.virtualPilotRateStdLimitBinsPerSec;
    if rateObservable
        ratePrior = min(bootstrapRate+parameters.rateDeviationLimitBinsPerSec, ...
            max(bootstrapRate-parameters.rateDeviationLimitBinsPerSec,vpRate));
        freezeRate = false;
    else
        ratePrior = bootstrapRate;
        freezeRate = true;
    end
    [centerCfo,rate] = localFit(historyTime,historyCfo,historyConfidence, ...
        historyPeak,targetTime,ratePrior,freezeRate,config,parameters);
    compensated = v4CompensateSymbol(observation.rxPhysical(row,:), ...
        phaseState,centerCfo,rate,config);
    if layout.kind(row) == "data"
        data = layout.dataIndex(row);
        decision = v4SymbolLikelihood(compensated,config);
        compensatedData(data,:) = compensated;
        hardPhysicalBins(data) = decision.physicalBin;
        decisionPeakRatio(data) = decision.peakRatio;
        predictedCfoBins(data) = centerCfo;
        predictedPhaseRad(data) = phaseState;
        activeHistoryCount(data) = historyCount;
    end
    phaseState = angle(exp(1i*(phaseState+2*pi*centerCfo)));
end
tracker = struct('compensatedData',compensatedData, ...
    'hardPhysicalBins',hardPhysicalBins,'decisionPeakRatio',decisionPeakRatio, ...
    'predictedCfoBins',predictedCfoBins,'predictedPhaseRad',predictedPhaseRad, ...
    'pilotAccepted',pilotAccepted, ...
    'pilotAppliedAtPhysicalRow',pilotAppliedAtPhysicalRow, ...
    'pilotAvailabilityPhysicalRow',availabilityRow, ...
    'activeHistoryCount',activeHistoryCount,'phasePairUsed',phasePairUsed, ...
    'finalHistoryTimeSec',historyTime,'finalHistoryCfoBins',historyCfo, ...
    'virtualPilotRateEvidenceCount',numel(vpRows), ...
    'initialRateBinsPerSec',bootstrapRate, ...
    'usesCrossFrameRate',isfinite(options.InitialRateBinsPerSec), ...
    'usesPayloadTruth',false,'usesOrbitTruth',false);
end

function [center,rate] = localFit(time,cfo,confidence,peak,target,ratePrior,freezeRate,config,parameters)
valid = isfinite(time) & isfinite(cfo);
time = time(valid); cfo = cfo(valid); confidence = confidence(valid); peak = peak(valid);
x = time-target;
ageSymbols = max(0,(target-time)/config.symbolDurationSec);
weight = parameters.historyDecay.^ageSymbols.*min(4,max(1,confidence)).* ...
    min(3,max(1,peak));
if freezeRate || numel(time) < 2
    rate = ratePrior;
    center = sum(weight.*(cfo-rate*x))/sum(weight);
else
    design = [ones(size(x)),x];
    beta = localWeightedFit(design,cfo,weight);
    for iteration = 1:2
        residual = cfo-design*beta;
        robust = min(1,parameters.huberThresholdBins./max(abs(residual),eps));
        beta = localWeightedFit(design,cfo,weight.*robust);
    end
    rate = min(parameters.maximumRateBinsPerSec,max( ...
        -parameters.maximumRateBinsPerSec,beta(2)));
    rate = min(ratePrior+parameters.rateDeviationLimitBinsPerSec, ...
        max(ratePrior-parameters.rateDeviationLimitBinsPerSec,rate));
    center = sum(weight.*(cfo-rate*x))/sum(weight);
end
end

function [rate,rateStd] = localVpRate(rows,cfo,layout,config,parameters)
if numel(rows) < 2
    rate = NaN;
    rateStd = Inf;
    return
end
time = layout.physicalCenterTimeSec(rows);
x = time-mean(time);
design = [ones(size(x)),x];
weight = ones(size(x));
beta = localWeightedFit(design,cfo,weight);
for iteration = 1:2
    residual = cfo-design*beta;
    weight = min(1,parameters.huberThresholdBins./max(abs(residual),eps));
    beta = localWeightedFit(design,cfo,weight);
end
rate = beta(2);
center = sum(weight.*x)/sum(weight);
information = sum(weight.*(x-center).^2);
rateStd = parameters.virtualPilotCfoStdBins/sqrt(max(information,eps));
if abs(rate) > parameters.maximumRateBinsPerSec
    rate = sign(rate)*parameters.maximumRateBinsPerSec;
end
if config.virtualPilotHistoryLength ~= 8
    error('V4:HistoryLength','V4 requires rolling-8 history.');
end
end

function beta = localWeightedFit(design,response,weight)
sqrtWeight = sqrt(max(weight,eps));
beta = (design.*sqrtWeight)\(response.*sqrtWeight);
end
