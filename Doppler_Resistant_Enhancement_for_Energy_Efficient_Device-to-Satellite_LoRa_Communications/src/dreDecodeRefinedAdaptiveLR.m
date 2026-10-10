function result = dreDecodeRefinedAdaptiveLR(rawBins,knownPreamble,config, ...
        samplePositions,historyLength,fitMethod)
%DREDECODEREFINEDADAPTIVELR Receiver-only variants of the paper's LR update.
%   The ten-point centroid and causal decision-directed error update stay
%   unchanged. Only the number of past errors and line-fitting rule vary.

rawBins = double(rawBins(:));
knownPreamble = double(knownPreamble(:));
positions = double(samplePositions(:));
m = config.samplesPerSymbol;
n = numel(knownPreamble);
historyLength = double(historyLength);
fitMethod = lower(string(fitMethod));
if n ~= config.preambleSymbolCount || numel(rawBins) <= n || ...
        numel(positions) ~= numel(rawBins) || any(diff(positions)<=0) || ...
        historyLength < n || historyLength ~= floor(historyLength) || ...
        ~ismember(fitMethod,["ordinary" "theil-sen"])
    error('DRE:RefinedShape','Invalid refined LR input or fitting rule.');
end

observedError = nan(size(rawBins));
observedError(1) = rawBins(1)-knownPreamble(1);
observedError(1) = observedError(1)-round(observedError(1)/m)*m;
for row=2:n
    base = rawBins(row)-knownPreamble(row);
    observedError(row) = base+round((observedError(row-1)-base)/m)*m;
end
detected = zeros(numel(rawBins)-n,1);
predictedError = zeros(size(detected));
for row=n+1:numel(rawBins)
    history = max(1,row-historyLength):row-1;
    [slope,intercept] = localFit(positions(history), ...
        observedError(history),fitMethod);
    prediction = slope*positions(row)+intercept;
    predictedError(row-n) = prediction;
    symbol = mod(round(rawBins(row)-prediction),m);
    detected(row-n) = symbol;
    lifted = rawBins(row)+round((symbol+prediction-rawBins(row))/m)*m;
    observedError(row) = lifted-symbol;
end
result = struct('detectedSymbols',detected, ...
    'predictedErrorBins',predictedError, ...
    'observedErrorBins',observedError, ...
    'historyLength',historyLength,'fitMethod',char(fitMethod), ...
    'usesPayloadTruth',false);
end

function [slope,intercept] = localFit(x,y,fitMethod)
x = double(x(:)); y = double(y(:));
if fitMethod=="ordinary"
    xMean = mean(x); yMean = mean(y);
    slope = sum((x-xMean).*(y-yMean))/sum((x-xMean).^2);
    intercept = yMean-slope*xMean;
else
    count = numel(x);
    pairSlope = zeros(count*(count-1)/2,1);
    index = 0;
    for a=1:count-1
        for b=a+1:count
            index = index+1;
            pairSlope(index) = (y(b)-y(a))/(x(b)-x(a));
        end
    end
    slope = median(pairSlope);
    intercept = median(y-slope*x);
end
end
