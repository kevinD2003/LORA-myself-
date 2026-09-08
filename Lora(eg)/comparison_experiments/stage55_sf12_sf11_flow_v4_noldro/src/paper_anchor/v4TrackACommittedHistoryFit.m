function fit=v4TrackACommittedHistoryFit(history,targetTime,parameters)
%V4TRACKACOMMITTEDHISTORYFIT Robust bounded fit of committed measurements.
time=[history.measurementTimeSec].'; cfo=[history.cfoCandidateBins].';
weight=min(4,max(1,[history.peakRatio].'));
age=(numel(history)-1:-1:0).'; weight=weight.*parameters.historyDecay.^age;
x=time-targetTime;
if numel(history)<2
    rate=0; center=cfo(end); residual=0;
else
    design=[ones(size(x)),x]; w=sqrt(max(weight,eps)); beta=(design.*w)\(cfo.*w);
    for iteration=1:2
        residualVector=cfo-design*beta;
        robust=min(1,parameters.huberThresholdBins./max(abs(residualVector),eps));
        w=sqrt(max(weight.*robust,eps)); beta=(design.*w)\(cfo.*w);
    end
    rate=beta(2); center=sum(weight.*(cfo-rate*x))/sum(weight);
    residual=max(abs(cfo-(center+rate*x)));
end
fit=struct('cfoBins',center,'rateBinsPerSec',rate,'maximumResidualBins',residual, ...
    'withinRateBound',abs(rate)<=parameters.maximumRateBinsPerSec, ...
    'withinResidualBound',residual<=parameters.branchResidualLimitBins);
end
