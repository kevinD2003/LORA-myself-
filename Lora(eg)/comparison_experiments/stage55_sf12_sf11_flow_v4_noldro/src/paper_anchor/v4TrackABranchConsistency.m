function decision=v4TrackABranchConsistency(pending,parameters,currentTime)
%V4TRACKABRANCHCONSISTENCY Select one unique causal pair without truth.
decision=struct('release',false,'indices',zeros(0,1),'rateBinsPerSec',NaN, ...
    'cfoAtCurrentBins',NaN,'ambiguous',false,'pairCount',0);
if numel(pending)<2,return,end
pairs=zeros(0,2); rates=zeros(0,1); endpoints=zeros(0,1);
for left=1:numel(pending)-1
    for right=left+1:numel(pending)
        dt=pending(right).measurementTimeSec-pending(left).measurementTimeSec;
        if dt<=0,continue,end
        rate=(pending(right).cfoCandidateBins-pending(left).cfoCandidateBins)/dt;
        if abs(rate)>parameters.maximumRateBinsPerSec,continue,end
        fit=pending(right).cfoCandidateBins+rate* ...
            ([pending.measurementTimeSec].'-pending(right).measurementTimeSec);
        residual=abs([pending.cfoCandidateBins].'-fit);
        if max(residual)>parameters.branchResidualLimitBins,continue,end
        pairs(end+1,:)=[left right]; %#ok<AGROW>
        rates(end+1,1)=rate; %#ok<AGROW>
        endpoints(end+1,1)=pending(right).cfoCandidateBins+rate* ...
            (currentTime-pending(right).measurementTimeSec); %#ok<AGROW>
    end
end
decision.pairCount=size(pairs,1);
if isempty(pairs),return,end
if max(endpoints)-min(endpoints)>parameters.branchResidualLimitBins || ...
        max(rates)-min(rates)>parameters.branchRateAgreementLimitBinsPerSec
    decision.ambiguous=true; return
end
[~,order]=sortrows([[pending(pairs(:,2)).measurementTimeSec].' ...
    [pending(pairs(:,1)).measurementTimeSec].'],[1 2]);
chosen=order(1); decision.release=true; decision.indices=pairs(chosen,:).';
decision.rateBinsPerSec=rates(chosen); decision.cfoAtCurrentBins=endpoints(chosen);
end
