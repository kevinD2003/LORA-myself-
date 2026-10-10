function result = referencePhyV6LR(raw,indices,preambleCount,alphabetSize,mode)
%REFERENCEPHYV6LR Ordinary causal LS on physical symbol times, including SFD gap.
% Only the first N zero-valued pilots are known; sync upchirps are hard-decided.
raw=double(raw);indices=double(indices(:));[count,replicates]=size(raw);
if count~=numel(indices) || count<=preambleCount || preambleCount<2 || ...
        any(~isfinite(raw(:))) || any(~isfinite(indices)) || any(diff(indices)<=0) || ...
        ~ismember(mode,{'fixed','adaptive'})
    error('ReferencePhyV6:LR','Invalid observation/time grid.');
end
errors=nan(count,replicates);
errors(1,:)=raw(1,:)-round(raw(1,:)/alphabetSize)*alphabetSize;
for row=2:preambleCount
    errors(row,:)=raw(row,:)+round((errors(row-1,:)-raw(row,:))/alphabetSize)*alphabetSize;
end
[fixedSlope,fixedIntercept]=localFit(indices(1:preambleCount),errors(1:preambleCount,:));
detected=zeros(count-preambleCount,replicates);
for row=preambleCount+1:count
    slope=fixedSlope;intercept=fixedIntercept;
    if strcmp(mode,'adaptive')
        history=row-preambleCount:row-1;
        [slope,intercept]=localFit(indices(history),errors(history,:));
    end
    prediction=slope*indices(row)+intercept;
    decision=mod(round(raw(row,:)-prediction),alphabetSize);
    detected(row-preambleCount,:)=decision;
    errors(row,:)=raw(row,:)+round((decision+prediction-raw(row,:))/alphabetSize)*alphabetSize-decision;
end
result=struct('detectedSymbols',detected,'observedErrorBins',errors, ...
    'mode',mode,'usesPayloadTruth',false,'regression','ordinary causal least squares');
end

function [slope,intercept]=localFit(x,y)
centered=x-mean(x);slope=sum(centered.*y,1)/sum(centered.^2);
intercept=mean(y,1)-slope*mean(x);
end
