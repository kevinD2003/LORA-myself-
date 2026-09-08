function report=buildV4ExperimentAReportR5()
root=v4SetupPaths();c=sf12NoLdroSf11FlowConfig();base=fullfile(root,'results','formal','track_a','R5-point-anchored');methods=["No-Doppler" "Paper-Point" "Paper-Midamble-Point-native" "Stage55-point-anchored"];
summaryRows=cell(80,17);pairedRows=cell(20,11);symbolRows=cell(20*4*23,8);sr=0;pr=0;yr=0;allSignatures=strings(20,1);
for caseIndex=1:2,for snrIndex=1:10
    snrDb=-31+snrIndex;path=fullfile(base,'A-3S-param-v01',sprintf('case_%d',caseIndex),sprintf('snr_%+03d',snrDb),'formal_cell.mat');x=load(path,'formalCell');f=x.formalCell;state=f.state;allSignatures((caseIndex-1)*10+snrIndex)=string(f.signature);
    for method=1:4
        sr=sr+1;errors=sum(double(state.symbolErrors(:,method)));count=f.fixedPackets*23;runtime=double(state.runtimeSec(:,method));accepted=0;falseAccepted=0;
        if method==4,accepted=sum(state.stageAccepted,'all');falseAccepted=sum(double(state.stageFalseAccepted));end
        summaryRows(sr,:)={caseIndex,f.caseStartTimeSec,snrDb,methods(method),f.fixedPackets,errors,count,errors/count,sum(state.cfoSseBins(:,method)),sqrt(sum(state.cfoSseBins(:,method))/count),sqrt(sum(state.cfoSseBins(:,method))/count)*c.fftBinSpacingHz,accepted,falseAccepted,falseAccepted/max(accepted,1),accepted/(f.fixedPackets*23),mean(runtime),sum(runtime>c.symbolDurationSec)};
        for data=1:23,yr=yr+1;truth=double(state.truthCfoBins(:,data));estimate=double(state.estimatedCfoBins(:,method,data));symbolRows(yr,:)={caseIndex,snrDb,methods(method),data,sqrt(mean((estimate-truth).^2)),c.fftBinSpacingHz,sqrt(mean((estimate-truth).^2))*c.fftBinSpacingHz,f.fixedPackets};end
    end
    difference=(double(state.symbolErrors(:,4))-double(state.symbolErrors(:,3)))/23;stream=RandStream('mt19937ar','Seed',770000000+caseIndex*100+snrIndex);draws=zeros(10000,1);
    if all(difference==difference(1)),half=2*sqrt(log(2/0.05)/(2*numel(difference)));lower=max(-1,mean(difference)-half);upper=min(1,mean(difference)+half);method="degenerate-bootstrap-Hoeffding";else
        for chunk=1:100,index=randi(stream,numel(difference),numel(difference),100);draws((chunk-1)*100+(1:100))=mean(difference(index),1).';end;bounds=prctile(draws,[2.5 97.5]);lower=bounds(1);upper=bounds(2);method="paired-packet-percentile";end
    pr=pr+1;halfWidth=(upper-lower)/2;pairedRows(pr,:)={caseIndex,f.caseStartTimeSec,snrDb,f.fixedPackets,mean(difference),lower,upper,halfWidth,halfWidth<=0.01,method,10000};
end,end
summary=cell2table(summaryRows,'VariableNames',{'caseIndex','caseStartTimeSec','snrDb','method','pairedPackets','symbolErrors','symbolCount','ser','cfoSseBins','cfoRmseBins','cfoRmseHz','vpAccepted','vpFalseAccepted','vpFalseAcceptance','vpCoverage','meanRuntimeSec','deadlineMisses'});
paired=cell2table(pairedRows,'VariableNames',{'caseIndex','caseStartTimeSec','snrDb','pairedPackets','stageMinusPaperDeltaSer','lower95','upper95','halfWidth','precisionTargetMet','ciMethod','bootstrapDraws'});
perSymbol=cell2table(symbolRows,'VariableNames',{'caseIndex','snrDb','method','dataIndex','cfoRmseBins','binSpacingHz','cfoRmseHz','packetCount'});
report=struct('planVersion','V4-noLDRO-plan-R5-track-a-point-anchored-lock','algorithmSignature','e9f0b53e2bb9d1a9497338201d96713827945a0c81927424236b3b8b4dbedb4b','cellSignatures',allSignatures,'fixedTotalPairedPackets',400000,'summary',summary,'pairedIntervals',paired,'perSymbolCfo',perSymbol,'reportsBitMetrics',false,'precisionInconclusivePoints',sum(~paired.precisionTargetMet));
out=fullfile(root,'results','reports');if ~isfolder(out),mkdir(out);end;save(fullfile(out,'experiment_a_report_data.mat'),'report','-v7.3');writetable(summary,fullfile(out,'EXPERIMENT_A_SUMMARY.csv'));writetable(paired,fullfile(out,'EXPERIMENT_A_PAIRED_CI.csv'));writetable(perSymbol,fullfile(out,'EXPERIMENT_A_PER_SYMBOL_CFO.csv'));localPlot(summary,methods,out);localMarkdown(fullfile(out,'EXPERIMENT_A_REPORT.md'),report);
end
function localPlot(summary,methods,out)
f=figure('Visible','off','Color','w');tiledlayout(1,2);for ci=1:2,nexttile;hold on;for m=1:4,rows=summary.caseIndex==ci&summary.method==methods(m);plot(summary.snrDb(rows),summary.ser(rows),'-o','DisplayName',methods(m));end;grid on;xlabel('SNR (dB)');ylabel('SER');title(sprintf('Track A Case %d',ci));legend('Location','best','Interpreter','none');end;exportgraphics(f,fullfile(out,'EXPERIMENT_A_SER.png'),'Resolution',160);close(f);
end
function localMarkdown(path,r)
f=fopen(path,'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,['# Experiment A formal report - R5\n\nPlan: `%s`.\n\nAlgorithm signature: `%s`.\n\n' ...
    'Fixed sample size: 20000 paired packets per Case/SNR, 400000 total. SNR=-30:-21 dB. CI uses 10000 paired-packet bootstrap draws.\n\n' ...
    'Track A reports SER and CFO/VP/runtime diagnostics only; no CR1 BER, PER, or information-bit goodput is produced.\n\n' ...
    'Precision-inconclusive points: %d. CI crossing zero, adverse performance, and realtime deadline misses are retained rather than treated as code failures.\n\n' ...
    'Data: `EXPERIMENT_A_SUMMARY.csv`, `EXPERIMENT_A_PAIRED_CI.csv`, `EXPERIMENT_A_PER_SYMBOL_CFO.csv`, `EXPERIMENT_A_SER.png`.\n'],r.planVersion,r.algorithmSignature,r.precisionInconclusivePoints);clear cl
end
