function result = dreDecodeLinearRegression(rawBins,knownPreamble,config,mode,samplePositions)
%DREDECODELINEARREGRESSION Equations (18)-(22), fixed or adaptive LR.

rawBins = double(rawBins(:));
knownPreamble = double(knownPreamble(:));
m = config.samplesPerSymbol;
nKnown = numel(knownPreamble);
if nKnown ~= config.preambleSymbolCount || numel(rawBins) < nKnown+1
    error('DRE:DecodeShape','Raw estimates and known preamble have invalid size.');
end
if ~ismember(lower(string(mode)),["fixed" "adaptive"])
    error('DRE:DecodeMode','Mode must be fixed or adaptive.');
end
if nargin < 5 || isempty(samplePositions)
    xAll = (0:numel(rawBins)-1).';
else
    xAll = double(samplePositions(:));
    if numel(xAll) ~= numel(rawBins) || any(diff(xAll) <= 0)
        error('DRE:SamplePositions','Sample positions must be strictly increasing.');
    end
end
errors = nan(size(rawBins));
first = rawBins(1)-knownPreamble(1);
first = first-round(first/m)*m;
errors(1) = first;
for k = 2:nKnown
    base = rawBins(k)-knownPreamble(k);
    errors(k) = base+round((errors(k-1)-base)/m)*m;
end
[fixedSlope,fixedIntercept] = localFit(xAll(1:nKnown),errors(1:nKnown));
detected = nan(numel(rawBins)-nKnown,1);
predictedError = nan(size(detected));
for k = nKnown+1:numel(rawBins)
    if strcmpi(mode,'fixed')
        slope = fixedSlope;
        intercept = fixedIntercept;
    else
        history = (k-nKnown):(k-1);
        [slope,intercept] = localFit(xAll(history),errors(history));
    end
    predictedError(k-nKnown) = slope*xAll(k)+intercept;
    corrected = rawBins(k)-predictedError(k-nKnown);
    detected(k-nKnown) = mod(round(corrected),m);
    rawLift = rawBins(k)+round((detected(k-nKnown)+ ...
        predictedError(k-nKnown)-rawBins(k))/m)*m;
    errors(k) = rawLift-detected(k-nKnown);
end
result = struct('detectedSymbols',detected,'predictedErrorBins',predictedError, ...
    'observedErrorBins',errors,'fixedSlopeBinsPerSymbol',fixedSlope, ...
    'fixedInterceptBins',fixedIntercept,'mode',char(lower(string(mode))), ...
    'usesPayloadTruth',false);
end

function [slope,intercept] = localFit(x,y)
x = double(x(:));
y = double(y(:));
xMean = mean(x);
yMean = mean(y);
denominator = sum((x-xMean).^2);
if denominator <= eps
    slope = 0;
else
    slope = sum((x-xMean).*(y-yMean))/denominator;
end
intercept = yMean-slope*xMean;
end
