function report=buildV4BCaseAnchorReportV1()
root=v4SetupPaths();snrs=(-30:-21).';cases=[-366 0];methods={'Huang','Stage55','Paper'};
metrics=zeros(2,10,3,4);raw=zeros(2,10,3,4);den=zeros(2,10,3,4);bounds=zeros(2,10,4,2);half=zeros(2,10,4);
rows=cell(2*10*3,16);row=0;
for ci=1:2
 for si=1:10
  path=fullfile(root,'results','case_anchor_b','B-case-anchor-AWGN-v1',sprintf('case_%d',ci),sprintf('snr_%+03d',snrs(si)),'formal_cell.mat');
  if ~isfile(path),error('V4:BCaseAnchorReport','Missing Case %d SNR %g.',ci,snrs(si));end
  x=load(path,'cellResult');r=x.cellResult;metrics(ci,si,:,:)=reshape(r.metrics,1,1,3,4);raw(ci,si,:,:)=reshape(r.rawErrors,1,1,3,4);den(ci,si,:,:)=reshape(r.denominators,1,1,3,4);
  packet=double(r.packetErrors);normalizer=reshape([112 768 768 1],1,1,4);perPacket=packet./normalizer;
  key=struct('planVersion','B-case-anchor-AWGN-v1','phase','paired-bootstrap','track','B-case-anchor', ...
   'channel','AWGN','comparisonMode','case-anchor-controlled','snrDb',snrs(si), ...
   'replicateId',ci,'packetId',0,'eventType','paired-packet-bootstrap','eventIndex',si,'sampleIndex',0,'component','resample');
  stream=RandStream('mt19937ar','Seed',v4KeyedSeed(581000000,key));draws=zeros(10000,4);
  for b=1:10000,idx=randi(stream,200,200,1);sample=mean(perPacket(idx,:,:),1);draws(b,:)=reshape(sample(1,2,:)-sample(1,3,:),1,4);end
  q=prctile(draws,[2.5 97.5]);bounds(ci,si,:,1)=q(1,:);bounds(ci,si,:,2)=q(2,:);half(ci,si,:)=(q(2,:)-q(1,:))/2;
  for method=1:3,row=row+1;rows(row,:)={ci,cases(ci),snrs(si),methods{method},200, ...
    r.initialCfoHz,r.initialCfoBins,r.initialRateHzPerSec,r.initialRateBinsPerSec, ...
    r.rawErrors(method,1),r.denominators(method,1),r.metrics(method,1), ...
    r.rawErrors(method,2),r.metrics(method,2),r.rawErrors(method,3),r.metrics(method,3)};end
 end
end
summary=cell2table(rows,'VariableNames',{'caseIndex','caseStartTimeSec','snrDb','method','pairedPackets', ...
 'initialCfoHz','initialCfoBins','initialRateHzPerSec','initialRateBinsPerSec', ...
 'symbolErrors','symbolCount','ser','hardBitErrors','hardBer','mlBitErrors','mlBer'});
out=fullfile(root,'results','reports');csvPath=fullfile(out,'B_CASE_ANCHOR_AWGN_V1_SUMMARY.csv');writetable(summary,csvPath);
colors=[.35 .35 .35;.85 .325 .098;0 .447 .741];styles={'-.^','-s','--o'};
plotMetrics=metrics;zero=plotMetrics==0;plotMetrics(zero)=0.5./den(zero);
f=figure('Visible','off','Color','w','Position',[100 100 1200 480]);tl=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
for ci=1:2,nexttile;for method=1:3,semilogy(snrs,squeeze(plotMetrics(ci,:,method,1)),styles{method},'Color',colors(method,:),'LineWidth',1.8,'MarkerSize',6,'DisplayName',methods{method});hold on;end;grid on;grid minor;xlabel('SNR (dB)');ylabel('SER');title(sprintf('Case %d: CFO %.1f bins, rate %.3f bins/s',ci,summary.initialCfoBins(find(summary.caseIndex==ci,1)),summary.initialRateBinsPerSec(find(summary.caseIndex==ci,1))));xlim([-30 -21]);ylim([1e-6 1.1]);legend('Location','southwest');end
title(tl,{'B coding under Case 1/Case 2 conditions: SER','Zero-error points displayed at 0.5/N'},'FontWeight','bold');serPng=fullfile(out,'B_CASE_ANCHOR_AWGN_V1_SER.png');serFig=fullfile(out,'B_CASE_ANCHOR_AWGN_V1_SER.fig');exportgraphics(f,serPng,'Resolution',220);savefig(f,serFig);close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1200 850]);tl=tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
for ci=1:2,for k=1:2,nexttile((ci-1)*2+k);metricIndex=k+1;metricName={'Hard BER','ML BER'};for method=1:3,semilogy(snrs,squeeze(plotMetrics(ci,:,method,metricIndex)),styles{method},'Color',colors(method,:),'LineWidth',1.8,'MarkerSize',6,'DisplayName',methods{method});hold on;end;grid on;grid minor;xlabel('SNR (dB)');ylabel(metricName{k});title(sprintf('Case %d - %s',ci,metricName{k}));xlim([-30 -21]);ylim([1e-7 1]);legend('Location','southwest');end,end
title(tl,{'B coding under Case 1/Case 2 conditions: BER','Zero-error points displayed at 0.5/N'},'FontWeight','bold');berPng=fullfile(out,'B_CASE_ANCHOR_AWGN_V1_BER.png');berFig=fullfile(out,'B_CASE_ANCHOR_AWGN_V1_BER.fig');exportgraphics(f,berPng,'Resolution',220);savefig(f,berFig);close(f);
stageMinusPaper=squeeze(metrics(:,:,2,:)-metrics(:,:,3,:));report=struct('status','PASS','identity','B-case-anchor-AWGN-v1', ...
 'pairedPacketsPerCaseSnr',200,'bootstrapDraws',10000,'caseStartTimeSec',cases, ...
 'metrics',metrics,'rawErrors',raw,'denominators',den,'stageMinusPaper',stageMinusPaper, ...
 'lower95',bounds(:,:,:,1),'upper95',bounds(:,:,:,2),'halfWidth',half, ...
 'summaryCsv',csvPath,'serPng',serPng,'berPng',berPng,'zeroErrorPlotConvention','0.5/N');
save(fullfile(out,'B_CASE_ANCHOR_AWGN_V1_REPORT.mat'),'report','-v7.3');write(fullfile(out,'B_CASE_ANCHOR_AWGN_V1_REPORT.json'),jsonencode(report,'PrettyPrint',true));
end
function write(path,text),f=fopen(path,'w','n','UTF-8');cl=onCleanup(@()fclose(f));fprintf(f,'%s\n',text);clear cl,end
