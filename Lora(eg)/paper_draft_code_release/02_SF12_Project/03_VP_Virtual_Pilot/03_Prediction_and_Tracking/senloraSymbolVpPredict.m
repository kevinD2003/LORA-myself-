function [center,rate,fit] = senloraSymbolVpPredict( ...
        history,targetTime,targetRow,c,parameters)
%SENLORASYMBOLVPPREDICT Causal, cluster-weighted Rolling-N correction fit.
% Same-block measurements share ML/labels; each source block has <=1 raw
% unit of weight. Rate information uses block mean times, not seven iid rows.
center = 0;
rate = 0;
fit = struct('historyCount',numel(history.symbolIndex), ...
    'timeSpanSec',0,'sourceBlockCount',0,'rateUpdated',false, ...
    'rateRejected',false,'rateStdBinsPerSec',parameters.virtualPilotCfoStdBins/sqrt(eps), ...
    'usedSymbolIndices',history.symbolIndex(:), ...
    'weight',zeros(numel(history.symbolIndex),1));
if isempty(history.symbolIndex)
    return
end
if any(history.availablePhysicalRow>targetRow) || ...
        any(history.availableTimeSec>targetTime) || ...
        any(history.symbolTimeSec>=targetTime)
    error('SymbolVp:FutureObservation','History is not available at this target.');
end
time = history.symbolTimeSec;
y = history.correctionCfoBins;
if any(~isfinite([time;y;history.confidence;history.residualPeakRatio]))
    error('SymbolVp:InvalidHistory','History must contain finite measurements.');
end
fit.timeSpanSec = max(time)-min(time);
blocks = unique(history.sourceBlock);
fit.sourceBlockCount = numel(blocks);
clusterTimes = zeros(numel(blocks),1);
clusterSize = ones(size(time));
for k = 1:numel(blocks)
    member = history.sourceBlock==blocks(k);
    clusterSize(member) = sum(member);
    clusterTimes(k) = mean(time(member));
end
age = max(0,(targetTime-time)/c.symbolDurationSec);
weight = parameters.historyDecay.^age.* ...
    min(4,max(1,history.confidence)).*min(3,max(1,history.residualPeakRatio));
% Normalize within each block, preserving decay between blocks.
for k = 1:numel(blocks)
    member = history.sourceBlock==blocks(k);
    weight(member) = weight(member)/(clusterSize(find(member,1))* ...
        max(1,max(weight(member))));
end
% Avoid underflow after a long rejection run; common scale cancels in fit.
if sum(weight)<=realmin
    weight = 1./clusterSize;
end
fit.weight = weight;
information = sum((clusterTimes-mean(clusterTimes)).^2);
fit.rateStdBinsPerSec = parameters.virtualPilotCfoStdBins/ ...
    sqrt(max(information,eps));
observable = numel(time)>=2 && numel(blocks)>=2 && ...
    fit.rateStdBinsPerSec<=parameters.virtualPilotRateStdLimitBinsPerSec;
x = time-targetTime;
if observable
    design = [ones(size(x)),x];
    beta = localWeightedFit(design,y,weight);
    for iteration = 1:2
        residual = y-design*beta;
        robust = min(1,parameters.huberThresholdBins./max(abs(residual),eps));
        beta = localWeightedFit(design,y,weight.*robust);
    end
    rate = min(parameters.rateDeviationLimitBinsPerSec, ...
        max(-parameters.rateDeviationLimitBinsPerSec,beta(2)));
    % Recenter after rate clipping, as in the existing rolling tracker.
    center = sum(weight.*(y-rate*x))/sum(weight);
    fit.rateUpdated = true;
else
    center = sum(weight.*y)/sum(weight);
    fit.rateRejected = true;
end
if ~all(isfinite([center rate]))
    error('SymbolVp:NonfiniteFit','Correction fit must be finite.');
end
end

function beta = localWeightedFit(design,response,weight)
rootWeight = sqrt(max(weight,eps));
beta = (design.*rootWeight)\(response.*rootWeight);
end
