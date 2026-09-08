function [rateBinsPerSec,state,diagnostic] = v4CrossFrameRateUpdate( ...
        state,measurementTimeSec,measuredCfoBins,fallbackRateBinsPerSec,config,parameters)
%V4CROSSFRAMERATEUPDATE Receiver-visible causal rolling-8 preamble CFO fit.

if isempty(fieldnames(state))
    time = zeros(0,1);
    cfo = zeros(0,1);
else
    time = state.measurementTimeSec(:);
    cfo = state.measuredCfoBins(:);
    if numel(time) ~= numel(cfo) || numel(time) > 8 || ...
            any(diff(time) <= 0) || measurementTimeSec <= time(end)
        error('V4:CrossFrameState','Cross-frame history must be ordered rolling-8.');
    end
end
time(end+1,1) = measurementTimeSec;
cfo(end+1,1) = measuredCfoBins;
if numel(time) > config.virtualPilotHistoryLength
    time = time(end-config.virtualPilotHistoryLength+1:end);
    cfo = cfo(end-config.virtualPilotHistoryLength+1:end);
end
count = numel(time);
x = time-time(end);
if count == 1
    rawRate = fallbackRateBinsPerSec;
    fitted = cfo;
    weight = 1;
    source = 'single-frame eight-preamble fallback';
else
    if count == 2
        design = [ones(count,1),x];
    else
        design = [ones(count,1),x,0.5*x.^2];
    end
    age = (count-1:-1:0).';
    baseWeight = parameters.historyDecay.^age;
    weight = baseWeight;
    beta = localWeightedFit(design,cfo,weight);
    for iteration = 1:2
        residual = cfo-design*beta;
        weight = baseWeight.*min(1,parameters.huberThresholdBins./max(abs(residual),eps));
        beta = localWeightedFit(design,cfo,weight);
    end
    rawRate = beta(2);
    fitted = design*beta;
    source = sprintf('rolling-%d causal preamble CFO fit',count);
end
rateBinsPerSec = min(parameters.maximumRateBinsPerSec,max( ...
    -parameters.maximumRateBinsPerSec,rawRate));
state = struct('measurementTimeSec',time,'measuredCfoBins',cfo, ...
    'rateBinsPerSec',rateBinsPerSec,'historyCount',count, ...
    'historyLength',8,'usesOrbitPrior',false,'usesPayloadTruth',false);
diagnostic = struct('source',source,'fittedCfoBins',fitted, ...
    'fitResidualBins',cfo-fitted,'robustWeight',weight, ...
    'usesOrbitPrior',false,'usesPayloadTruth',false);
end

function beta = localWeightedFit(design,response,weight)
sqrtWeight = sqrt(max(weight,eps));
beta = (design.*sqrtWeight)\(response.*sqrtWeight);
end

