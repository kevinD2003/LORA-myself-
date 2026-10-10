function report = build_strict_formal_report()
%BUILD_STRICT_FORMAL_REPORT Independent overpass uncertainty and comparison.
folder=strictPaperSetup();
output=fullfile(folder,'results','full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20');
loaded=load(fullfile(output,'full_phy.mat'),'result');formal=loaded.result;
assert(strcmp(formal.status,'COMPLETE') && formal.formal3000Overpasses && ...
    numel(formal.conditions)==10 && formal.config.fullPhyOverpasses==3000);
identity=strictPaperIdentity(formal.config,'run_strict_full_phy.m');
assert(strcmp(formal.signature,dreConfigurationSignature(identity)));
summary=formal.table;
names={'adaptiveBerLow95','adaptiveBerHigh95','fixedBerLow95','fixedBerHigh95', ...
    'adaptivePlrLow95','adaptivePlrHigh95','fixedPlrLow95','fixedPlrHigh95', ...
    'adaptiveMeanOverpassBerPercent','fixedMeanOverpassBerPercent'};
for name=names,summary.(name{1})=nan(10,1);end
for index=1:10
    current=formal.conditions(index);counts=current.rawCounts.passCounts;
    stream=RandStream('mt19937ar','Seed',30103000+index);
    samplesBer=nan(2000,2);samplesPlr=zeros(2000,2);
    for draw=1:2000
        selected=randi(stream,3000,3000,1);
        denominator=sum(counts.codedBitsAccepted(selected,:),1);
        numerator=sum(counts.codedErrorsAccepted(selected,:),1);
        samplesBer(draw,denominator>0)=100*numerator(denominator>0)./denominator(denominator>0);
        samplesPlr(draw,:)=100*sum(counts.packetLosses(selected,:),1)/ ...
            (3000*current.packetCount);
    end
    berBounds=prctile(samplesBer,[2.5 97.5],1);
    plrBounds=prctile(samplesPlr,[2.5 97.5],1);
    summary.adaptiveBerLow95(index)=berBounds(1,1);
    summary.adaptiveBerHigh95(index)=berBounds(2,1);
    summary.fixedBerLow95(index)=berBounds(1,2);
    summary.fixedBerHigh95(index)=berBounds(2,2);
    summary.adaptivePlrLow95(index)=plrBounds(1,1);
    summary.adaptivePlrHigh95(index)=plrBounds(2,1);
    summary.fixedPlrLow95(index)=plrBounds(1,2);
    summary.fixedPlrHigh95(index)=plrBounds(2,2);
    for method=1:2
        valid=counts.codedBitsAccepted(:,method)>0;
        meanOverpass=100*mean(counts.codedErrorsAccepted(valid,method)./ ...
            counts.codedBitsAccepted(valid,method));
        if method==1,summary.adaptiveMeanOverpassBerPercent(index)=meanOverpass;
        else,summary.fixedMeanOverpassBerPercent(index)=meanOverpass;end
    end
end
reportIdentity=strictPaperIdentity(formal.config,'build_strict_formal_report.m');
report=struct('status','FORMAL_REPORT_COMPLETE','table',summary, ...
    'bootstrapDraws',2000,'bootstrapUnit','independent overpass', ...
    'formalSignature',formal.signature,'identity',reportIdentity, ...
    'signature',dreConfigurationSignature(reportIdentity), ...
    'numericalAgreementClaimed',false);
save(fullfile(output,'formal_comparison.mat'),'report','-v7.3');
writetable(summary,fullfile(output,'formal_comparison.csv'));
disp(summary(:,{'cr','snrDb','adaptiveBerPercent','paperAdaptiveBerPercent', ...
    'adaptivePlrPercent','paperAdaptivePlrPercent','fixedBerPercent', ...
    'paperFixedBerPercent','fixedPlrPercent','paperFixedPlrPercent'}));
end
