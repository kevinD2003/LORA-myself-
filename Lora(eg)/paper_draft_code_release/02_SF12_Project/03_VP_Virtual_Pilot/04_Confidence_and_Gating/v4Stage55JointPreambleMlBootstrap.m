function estimate = v4Stage55JointPreambleMlBootstrap(rxPilots,c,options)
%V4STAGE55JOINTPREAMBLEMLBOOTSTRAP Joint CFO/rate ML on known preambles.
%
% The eight dechirped preambles form one continuous polynomial-phase tone.
% A rate hypothesis removes the quadratic phase and a 32768-point FFT then
% estimates the CFO at the start of the first preamble.  Only known training
% samples are used; payload decisions, case identity and orbit truth are not.

arguments
    rxPilots (:,:) double
    c (1,1) struct
    options.MaximumRateBinsPerSec (1,1) double {mustBePositive} = 20
    options.CoarseRateStepBinsPerSec (1,1) double {mustBePositive} = 1
    options.FineRateStepBinsPerSec (1,1) double {mustBePositive} = 0.1
end

pilotCount = c.bootstrapPilotCount;
m = c.samplesPerSymbol;
if size(rxPilots,1) ~= pilotCount || size(rxPilots,2) ~= m
    error('V4:JointPreambleShape','Eight complete preambles are required.');
end

down = conj(v4ModulateSymbol(0,c));
dechirped = reshape((rxPilots.*repmat(down,pilotCount,1)).',[],1);
sampleTimeSymbols = (0:numel(dechirped)-1).'/m;

coarseRates = (-options.MaximumRateBinsPerSec: ...
    options.CoarseRateStepBinsPerSec:options.MaximumRateBinsPerSec).';
[coarseMetric,coarseCfo] = localSearch( ...
    dechirped,sampleTimeSymbols,coarseRates,c);
[~,coarseBest] = max(coarseMetric);
fineHalfWidth = options.CoarseRateStepBinsPerSec;
fineRates = (coarseRates(coarseBest)-fineHalfWidth: ...
    options.FineRateStepBinsPerSec: ...
    coarseRates(coarseBest)+fineHalfWidth).';
fineRates = fineRates(abs(fineRates) <= options.MaximumRateBinsPerSec);
[fineMetric,fineCfo] = localSearch( ...
    dechirped,sampleTimeSymbols,fineRates,c);
[peakMetric,best] = max(fineMetric);
initial = [fineCfo(best) fineRates(best)];
cfoWindow = c.samplesPerSymbol/numel(dechirped);
rateWindow = 2*options.CoarseRateStepBinsPerSec;
objective = @(x)localObjective(x,dechirped,sampleTimeSymbols,c, ...
    initial,cfoWindow,rateWindow,options.MaximumRateBinsPerSec);
solverOptions = optimset('Display','off','TolX',1e-7,'TolFun',1e-10, ...
    'MaxIter',80,'MaxFunEvals',160);
refined = fminsearch(objective,initial,solverOptions);
refined(1) = min(initial(1)+cfoWindow,max(initial(1)-cfoWindow,refined(1)));
refined(2) = min(options.MaximumRateBinsPerSec,max( ...
    -options.MaximumRateBinsPerSec,refined(2)));
peakMetric = -localObjective(refined,dechirped,sampleTimeSymbols,c, ...
    refined,Inf,Inf,options.MaximumRateBinsPerSec);
ratePerSymbol = refined(2)*c.symbolDurationSec;
phaseCycles = refined(1)*sampleTimeSymbols+ ...
    0.5*ratePerSymbol*sampleTimeSymbols.^2;
coherent = sum(dechirped.*exp(-1i*2*pi*phaseCycles));

ordered = sort(fineMetric,'descend');
if numel(ordered) > 1
    ratePeakRatio = ordered(1)/max(ordered(2),eps);
else
    ratePeakRatio = Inf;
end
estimate = struct( ...
    'cfoAtFirstPreambleStartBins',refined(1), ...
    'rateBinsPerSec',refined(2), ...
    'phaseAtFirstPreambleStartRad',angle(coherent), ...
    'peakMetric',peakMetric, ...
    'ratePeakRatio',ratePeakRatio, ...
    'coarseRateCandidatesBinsPerSec',coarseRates, ...
    'coarseMetric',coarseMetric, ...
    'fineRateCandidatesBinsPerSec',fineRates, ...
    'fineMetric',fineMetric, ...
    'usesPayloadTruth',false,'usesOrbitTruth',false, ...
    'source','eight-known-preamble joint polynomial-phase ML');
end

function value = localObjective(x,dechirped,timeSymbols,c,center,cfoWindow,rateWindow,maxRate)
if abs(x(1)-center(1)) > cfoWindow || ...
        abs(x(2)-center(2)) > rateWindow || abs(x(2)) > maxRate
    value = 1+abs(x(1)-center(1))+abs(x(2)-center(2));
    return
end
ratePerSymbol = x(2)*c.symbolDurationSec;
phaseCycles = x(1)*timeSymbols+0.5*ratePerSymbol*timeSymbols.^2;
coherent = sum(dechirped.*exp(-1i*2*pi*phaseCycles));
value = -abs(coherent)^2/numel(dechirped)^2;
end

function [metric,cfoBins] = localSearch(dechirped,timeSymbols,rates,c)
n = numel(dechirped);
metric = zeros(numel(rates),1);
cfoBins = zeros(numel(rates),1);
for k = 1:numel(rates)
    ratePerSymbol = rates(k)*c.symbolDurationSec;
    corrected = dechirped.*exp(-1i*pi*ratePerSymbol*timeSymbols.^2);
    spectrum = abs(fft(corrected)).^2;
    [peak,index] = max(spectrum);
    left = spectrum(mod(index-2,n)+1);
    right = spectrum(mod(index,n)+1);
    curvature = left-2*peak+right;
    if curvature < 0
        fractional = 0.5*(left-right)/curvature;
        fractional = min(0.5,max(-0.5,fractional));
    else
        fractional = 0;
    end
    metric(k) = peak-0.25*(left-right)*fractional;
    signed = index-1;
    if signed >= n/2
        signed = signed-n;
    end
    cfoBins(k) = (signed+fractional)*c.samplesPerSymbol/n;
end
end
