function result = dreDecodeLinearRegressionBatch(rawBins,preambleCount,alphabetSize,mode)
%DREDECODELINEARREGRESSIONBATCH Vectorized causal LR over many overpasses.

rawBins = double(rawBins);
[symbolCount,replicates] = size(rawBins);
if preambleCount < 2 || symbolCount <= preambleCount
    error('DRE:BatchDecodeShape','Batch decoder dimensions are invalid.');
end
if ~ismember(lower(string(mode)),["fixed" "adaptive"])
    error('DRE:DecodeMode','Mode must be fixed or adaptive.');
end
x = (0:symbolCount-1).';
errors = nan(symbolCount,replicates);
errors(1,:) = rawBins(1,:)-round(rawBins(1,:)/alphabetSize)*alphabetSize;
for row = 2:preambleCount
    base = rawBins(row,:);
    errors(row,:) = base+round((errors(row-1,:)-base)/alphabetSize)*alphabetSize;
end
[fixedSlope,fixedIntercept] = localFitBatch(x(1:preambleCount), ...
    errors(1:preambleCount,:));
detected = zeros(symbolCount-preambleCount,replicates);
for row = preambleCount+1:symbolCount
    if strcmpi(mode,'fixed')
        slope = fixedSlope;
        intercept = fixedIntercept;
    else
        history = row-preambleCount:row-1;
        [slope,intercept] = localFitBatch(x(history),errors(history,:));
    end
    prediction = slope*x(row)+intercept;
    corrected = rawBins(row,:)-prediction;
    decision = mod(round(corrected),alphabetSize);
    detected(row-preambleCount,:) = decision;
    lifted = rawBins(row,:)+round((decision+prediction-rawBins(row,:))/ ...
        alphabetSize)*alphabetSize;
    errors(row,:) = lifted-decision;
end
result = struct('detectedSymbols',detected,'observedErrorBins',errors, ...
    'mode',char(lower(string(mode))),'usesPayloadTruth',false);
end

function [slope,intercept] = localFitBatch(x,y)
x = double(x(:));
xMean = mean(x);
yMean = mean(y,1);
denominator = sum((x-xMean).^2);
slope = sum((x-xMean).*(y-yMean),1)/denominator;
intercept = yMean-slope*xMean;
end

