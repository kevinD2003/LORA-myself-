function [rateBinsPerSec,state,diagnostic] = ...
        satelliteFig3CrossFrameRateUpdate(state,measurementTimeSec, ...
        measuredCfoBins,fallbackRateBinsPerSec,config)
%SATELLITEFIG3CROSSFRAMERATEUPDATE Causal rolling-8 frame-rate state.
%   The eight known preambles in one 65.536-ms frame do not provide a
%   sufficiently long rate baseline at -20/-21 dB.  This receiver-only
%   state retains the aggregate Huang CFO from at most eight consecutive
%   frames.  A local quadratic fit supplies the rate at the current
%   preamble time without using trajectory or payload truth.

arguments
    state (1,1) struct
    measurementTimeSec (1,1) double {mustBeFinite}
    measuredCfoBins (1,1) double {mustBeFinite}
    fallbackRateBinsPerSec (1,1) double {mustBeFinite}
    config (1,1) struct
end

historyLength = config.virtualPilotHistoryLength;
if isempty(fieldnames(state))
    time = zeros(0,1);
    cfo = zeros(0,1);
else
    required = {'measurementTimeSec','measuredCfoBins'};
    for fieldIndex = 1:numel(required)
        if ~isfield(state,required{fieldIndex})
            error('SatelliteFig3:CrossFrameStateField', ...
                'Cross-frame state is missing field %s.',required{fieldIndex});
        end
    end
    time = state.measurementTimeSec(:);
    cfo = state.measuredCfoBins(:);
    if numel(time) ~= numel(cfo) || numel(time) > historyLength || ...
            any(~isfinite(time)) || any(~isfinite(cfo)) || ...
            any(diff(time) <= 0)
        error('SatelliteFig3:CrossFrameStateShape', ...
            'Cross-frame CFO history must be finite, ordered, and rolling-8.');
    end
    if ~isempty(time) && measurementTimeSec <= time(end)
        error('SatelliteFig3:CrossFrameStateTime', ...
            'Cross-frame measurements must arrive in strictly causal order.');
    end
end

time(end+1,1) = measurementTimeSec;
cfo(end+1,1) = measuredCfoBins;
if numel(time) > historyLength
    time = time(end-historyLength+1:end);
    cfo = cfo(end-historyLength+1:end);
end

count = numel(time);
x = time-time(end);
if count == 1
    rawRate = fallbackRateBinsPerSec;
    fittedCfo = cfo;
    robustWeight = 1;
    source = 'single-frame known-preamble phase fallback';
else
    if count == 2
        design = [ones(count,1),x];
        source = 'two-frame causal CFO slope';
    else
        design = [ones(count,1),x,0.5*x.^2];
        source = sprintf('rolling-%d causal quadratic CFO fit',count);
    end
    age = (count-1:-1:0).';
    baseWeight = config.historyDecay.^age;
    robustWeight = baseWeight;
    beta = localWeightedFit(design,cfo,robustWeight);
    for iteration = 1:2
        residual = cfo-design*beta;
        robustWeight = baseWeight.*min(1, ...
            config.huberThresholdBins./max(abs(residual),eps));
        beta = localWeightedFit(design,cfo,robustWeight);
    end
    rawRate = beta(2);
    fittedCfo = design*beta;
end
rateBinsPerSec = min(config.maxRateBinsPerSec,max( ...
    -config.maxRateBinsPerSec,rawRate));

state = struct( ...
    'measurementTimeSec',time, ...
    'measuredCfoBins',cfo, ...
    'rateBinsPerSec',rateBinsPerSec, ...
    'historyCount',count, ...
    'historyLength',historyLength, ...
    'usesTrajectoryPrior',false, ...
    'usesPayloadTruth',false);
diagnostic = struct( ...
    'source',source, ...
    'historyCount',count, ...
    'rawRateBinsPerSec',rawRate, ...
    'rateBinsPerSec',rateBinsPerSec, ...
    'measurementTimeSec',time, ...
    'measuredCfoBins',cfo, ...
    'fittedCfoBins',fittedCfo, ...
    'fitResidualBins',cfo-fittedCfo, ...
    'robustWeight',robustWeight, ...
    'usesTrajectoryPrior',false, ...
    'usesPayloadTruth',false);
end

function beta = localWeightedFit(design,response,weight)
sqrtWeight = sqrt(max(weight,eps));
beta = (design.*sqrtWeight)\(response.*sqrtWeight);
end
