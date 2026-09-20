function result = v4PaperMidamblePointTrendDecodeV3(observation,c)
%V4PAPERMIDAMBLEPOINTTRENDDECODEV3 Causal trend-aided Point updates.
%
% Each known pilot remains an integer full-FFT Point measurement.  The
% slope between the two most recent Point measurements predicts CFO over
% the next interval.  No payload decision, case identifier, SNR, orbit or
% truth value is used.

layout = observation.layout;
lastBootstrapRow = layout.bootstrapRows(end);
initial = v4PaperRefinedPointEstimate( ...
    observation.rxPhysical(lastBootstrapRow,:),0,c);
anchorCfo = initial.offsetBins;
anchorTime = layout.physicalCenterTimeSec(lastBootstrapRow);
rateBinsPerSec = 0;
maximumRateBinsPerSec = 20;
historyLength = 8;
historyTime = anchorTime;
historyCfo = anchorCfo;
updateDelayDataSymbols = 2;
trendPeakRatioThreshold = 1.5;
pendingAnchorCfo = NaN;
pendingAnchorTime = NaN;
pendingRateBinsPerSec = NaN;
remainingUpdateDelay = 0;

compensatedData = complex(zeros(c.payloadSymbolCount,c.samplesPerSymbol));
estimatedCfoBins = nan(c.payloadSymbolCount,1);
estimatedRateBinsPerSec = nan(c.payloadSymbolCount,1);
explicitAccepted = false(c.paperMidambleCount,1);
midambleResidualBins = nan(c.paperMidambleCount,1);
midamblePointCfoBins = nan(c.paperMidambleCount,1);
midambleRateBinsPerSec = nan(c.paperMidambleCount,1);
midambleGlobalPeakRatio = nan(c.paperMidambleCount,1);
midambleTrendAccepted = false(c.paperMidambleCount,1);
midambleTrendGain = zeros(c.paperMidambleCount,1);
firstEffectiveDataIndex = nan(c.paperMidambleCount,1);
midamble = 0;
for row = c.bootstrapPilotCount+1:layout.physicalSymbolCount
    centerTime = layout.physicalCenterTimeSec(row);
    predictedCfo = anchorCfo+rateBinsPerSec*(centerTime-anchorTime);
    compensated = v4CompensateSymbol(observation.rxPhysical(row,:), ...
        0,predictedCfo,rateBinsPerSec,c);
    if layout.kind(row) == "data"
        data = layout.dataIndex(row);
        compensatedData(data,:) = compensated;
        estimatedCfoBins(data) = predictedCfo;
        estimatedRateBinsPerSec(data) = rateBinsPerSec;
        if remainingUpdateDelay > 0
            remainingUpdateDelay = remainingUpdateDelay-1;
            if remainingUpdateDelay == 0
                anchorCfo = pendingAnchorCfo;
                anchorTime = pendingAnchorTime;
                rateBinsPerSec = pendingRateBinsPerSec;
                pendingAnchorCfo = NaN;
                pendingAnchorTime = NaN;
                pendingRateBinsPerSec = NaN;
            end
        end
    elseif layout.kind(row) == "midamble"
        midamble = midamble+1;
        residual = v4PaperLocalResidualEstimate( ...
            compensated,c,maximumRateBinsPerSec);
        measuredCfo = predictedCfo+residual.offsetBins;
        historyTime(end+1,1) = centerTime; %#ok<AGROW>
        historyCfo(end+1,1) = measuredCfo; %#ok<AGROW>
        if numel(historyTime) > historyLength
            historyTime = historyTime(end-historyLength+1:end);
            historyCfo = historyCfo(end-historyLength+1:end);
        end
        [fittedCfo,newRate] = localPointFit( ...
            historyTime,historyCfo,centerTime,maximumRateBinsPerSec);
        trendAccepted = residual.globalFftPeakRatio >= trendPeakRatioThreshold;
        trendGain = double(trendAccepted);
        if trendAccepted
            pendingAnchorCfo = fittedCfo;
            pendingRateBinsPerSec = newRate;
        else
            pendingAnchorCfo = measuredCfo;
            pendingRateBinsPerSec = 0;
        end
        pendingAnchorTime = centerTime;
        remainingUpdateDelay = updateDelayDataSymbols;
        midambleResidualBins(midamble) = residual.offsetBins;
        midamblePointCfoBins(midamble) = measuredCfo;
        midambleRateBinsPerSec(midamble) = newRate;
        midambleGlobalPeakRatio(midamble) = residual.globalFftPeakRatio;
        midambleTrendAccepted(midamble) = trendAccepted;
        midambleTrendGain(midamble) = trendGain;
        explicitAccepted(midamble) = true;
        nextData = layout.midambleAfterDataIndex(midamble)+1;
        if nextData <= c.payloadSymbolCount
            firstEffectiveDataIndex(midamble) = nextData;
        end
    end
end
decoded = v4DecodePayload(compensatedData,c,observation.noiseVariance);
result = struct('methodName',c.methodNames{3}, ...
    'algorithmVersion','Paper-Midamble-Point-local-trend-v5', ...
    'detectedPhysicalBins',decoded.hardPhysicalBins, ...
    'hardDecodedDataBits',decoded.hardDataBits, ...
    'softDecodedDataBits',decoded.softDataBits, ...
    'estimatedCfoBins',estimatedCfoBins, ...
    'estimatedRateBinsPerSec',estimatedRateBinsPerSec, ...
    'virtualPilotAccepted',false(c.payloadSymbolCount,1), ...
    'explicitMidambleAccepted',explicitAccepted, ...
    'pilotFirstEffectiveDataIndex',firstEffectiveDataIndex, ...
    'midambleResidualBins',midambleResidualBins, ...
    'midamblePointCfoBins',midamblePointCfoBins, ...
    'midambleRateBinsPerSec',midambleRateBinsPerSec, ...
    'midambleGlobalPeakRatio',midambleGlobalPeakRatio, ...
    'midambleTrendAccepted',midambleTrendAccepted, ...
    'midambleTrendGain',midambleTrendGain, ...
    'initialPointEstimate',initial, ...
    'paperMidambleInterval',c.paperMidambleInterval, ...
    'pointResolutionBins',0.25,'usesPayloadTruth',false, ...
    'usesOrbitTruth',false,'usesPayloadFeedback',false, ...
    'usesDopplerRate',true,'maximumRateBinsPerSec',maximumRateBinsPerSec, ...
    'pointHistoryLength',historyLength, ...
    'midambleUpdateDelayDataSymbols',updateDelayDataSymbols, ...
    'trendPeakRatioThreshold',trendPeakRatioThreshold, ...
    'fftCount',1+c.payloadSymbolCount+c.paperMidambleCount);
end

function [cfo,rate] = localPointFit(time,measurement,target,maxRate)
x = time-target;
design = [ones(size(x)) x];
weight = ones(size(x));
beta = design\measurement;
for iteration = 1:2
    residual = measurement-design*beta;
    weight = min(1,0.5./max(abs(residual),eps));
    rootWeight = sqrt(weight);
    beta = (design.*rootWeight)\(measurement.*rootWeight);
end
rate = min(maxRate,max(-maxRate,beta(2)));
cfo = sum(weight.*(measurement-rate*x))/sum(weight);
end
