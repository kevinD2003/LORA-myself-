function mode=v4Stage55ObservableModeSelectorV10(rxPilots,c,parameters)
%V4STAGE55OBSERVABLEMODESELECTORV10 Receiver-only static/dynamic evidence.
classification=v4Stage55PreambleRegimeClassifier(rxPilots,c, ...
    MaximumRateBinsPerSec=parameters.maximumRateBinsPerSec);
if isfield(parameters,'modeLargeToCentralRatio')
    threshold=parameters.modeLargeToCentralRatio;
else
    threshold=1;
end
ratio=classification.largeDomainScore/max(classification.centralDomainScore,eps);
staticSelected=ratio>=threshold;
mode=struct('selected',ternary(staticSelected,'static','dynamic'), ...
    'staticSelected',staticSelected,'largeToCentralScoreRatio',ratio, ...
    'decisionThreshold',threshold,'classification',classification, ...
    'usesCaseIdentity',false,'usesSnrInput',false,'usesTruth',false);
end
function value=ternary(condition,a,b)
if condition,value=a;else,value=b;end
end

