function [prediction,receiver] = referenceSoftPredictions(raw,indices,c,mode)
%REFERENCESOFTPREDICTIONS Expose pre-decision OLS estimates without soft feedback.
receiver=referencePhyV6LR(raw,indices,c.preambleSymbolCount,2^c.sf,mode);
x=double(indices(:));n=c.preambleSymbolCount;
prediction=nan(size(raw));errors=receiver.observedErrorBins;
for row=n+1:numel(x)
    history=1:n;
    if strcmp(mode,'adaptive'),history=row-n:row-1;end
    centered=x(history)-mean(x(history));
    slope=sum(centered.*errors(history,:),1)/sum(centered.^2);
    intercept=mean(errors(history,:),1)-slope*mean(x(history));
    prediction(row,:)=slope*x(row)+intercept;
end
assert(isequal(receiver.detectedSymbols, ...
    mod(round(raw(n+1:end,:)-prediction(n+1:end,:)),2^c.sf)));
end
