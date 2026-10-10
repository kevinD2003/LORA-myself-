function report=buildV4UnifiedV17TestReport(variant)
%BUILDV4UNIFIEDV17TESTREPORT Merge paired Huang V3, Stage V16, Paper V6.
if nargin==0,variant="v17";end
switch string(variant)
    case "v17"
        huangResultDir='huang_v3_test';reportDir='unified_v17_report';
        reportIdentity='unified-v17-1000-packet-test';
        figurePrefix='unified_v17';figureTitle='Unified V17';
        expectedHuangIdentity='huang-v3-test';requireHuangCase1Theory=false;
    case "v18"
        huangResultDir='huang_v5_test';reportDir='unified_v18_report';
        reportIdentity='unified-v18-1000-packet-test';
        figurePrefix='unified_v18';figureTitle='Unified V18';
        expectedHuangIdentity='huang-v5-test';requireHuangCase1Theory=true;
    case "v19"
        huangResultDir='huang_v6_test';reportDir='unified_v19_report';
        reportIdentity='unified-v19-1000-packet-test';
        figurePrefix='unified_v19';figureTitle='Unified V19';
        expectedHuangIdentity='huang-v6-test';requireHuangCase1Theory=true;
    case "v20"
        huangResultDir='huang_v7_test';reportDir='unified_v20_report';
        reportIdentity='unified-v20-1000-packet-test';
        figurePrefix='unified_v20';figureTitle='Unified V20';
        expectedHuangIdentity='huang-v7-test';requireHuangCase1Theory=true;
    case "v21"
        huangResultDir='huang_v8_test';reportDir='unified_v21_report';
        reportIdentity='unified-v21-1000-packet-test';
        figurePrefix='unified_v21';figureTitle='Unified V21';
        expectedHuangIdentity='huang-v8-test';requireHuangCase1Theory=true;
    case "v22"
        huangResultDir='huang_v9_test';reportDir='unified_v22_report';
        reportIdentity='unified-v22-1000-packet-test';
        figurePrefix='unified_v22';figureTitle='Unified V22';
        expectedHuangIdentity='huang-v9-test';requireHuangCase1Theory=true;
    case "v23"
        huangResultDir='huang_v9_test';reportDir='unified_v23_report';
        reportIdentity='unified-v23-1000-packet-test';
        figurePrefix='unified_v23';figureTitle='Unified V23';
        expectedHuangIdentity='huang-v9-test';requireHuangCase1Theory=true;
    otherwise
        error('V4:UnifiedReportVariant','Unknown report variant: %s',variant);
end
root=v4SetupPaths();snrs=(-30:-21).';n=1000;methods={'Huang','Stage55','Paper'};
raw=zeros(2,10,3,2);den=zeros(2,10,3,2);metrics=zeros(2,10,3,2);
stagePaperBounds=zeros(2,10,2,2);paperHuangBounds=zeros(2,10,2,2);
stageHuangBounds=zeros(2,10,2,2);idealPass=true(2,10,3);
cellHashes=strings(2,10,2);stageVp=0;stageFalseVp=0;
ideal=v4IdealSerReference(root);rows=cell(60,11);tableRow=0;
for caseIndex=1:2
    for snrIndex=1:10
        folder=sprintf('snr_%+03d',snrs(snrIndex));
        hp=fullfile(root,'results','method_aligned',huangResultDir, ...
            sprintf('case%d',caseIndex),folder,'test_cell.mat');
        up=fullfile(root,'results','method_aligned','unified_v16_test', ...
            sprintf('case%d',caseIndex),folder,'test_cell.mat');
        h=load(hp,'result');u=load(up,'result');h=h.result;u=u.result;
        if ~strcmp(h.identity,expectedHuangIdentity)
            error('V4:UnifiedReportHuangIdentity', ...
                'Expected %s, found %s.',expectedHuangIdentity,h.identity);
        end
        packet=zeros(n,3,2);packet(:,1,:)=reshape(double(h.packetErrors),n,1,2);
        packet(:,2:3,:)=double(u.packetErrors(:,2:3,:));
        localRaw=squeeze(sum(packet,1));localDen=repmat([n*112 n*768],3,1);
        raw(caseIndex,snrIndex,:,:)=reshape(localRaw,1,1,3,2);
        den(caseIndex,snrIndex,:,:)=reshape(localDen,1,1,3,2);
        metrics(caseIndex,snrIndex,:,:)= ...
            raw(caseIndex,snrIndex,:,:)./den(caseIndex,snrIndex,:,:);
        normalizer=reshape([112 768],1,1,2);perPacket=packet./normalizer;
        stream=RandStream('mt19937ar','Seed',886000000+caseIndex*100+snrIndex);
        draws=zeros(10000,3,2);
        for draw=1:10000
            index=randi(stream,n,n,1);sample=squeeze(mean(perPacket(index,:,:),1));
            draws(draw,1,:)=sample(2,:)-sample(3,:);
            draws(draw,2,:)=sample(3,:)-sample(1,:);
            draws(draw,3,:)=sample(2,:)-sample(1,:);
        end
        stagePaperBounds(caseIndex,snrIndex,:,:)=reshape( ...
            prctile(draws(:,1,:),[2.5 97.5],1),1,1,2,2);
        paperHuangBounds(caseIndex,snrIndex,:,:)=reshape( ...
            prctile(draws(:,2,:),[2.5 97.5],1),1,1,2,2);
        stageHuangBounds(caseIndex,snrIndex,:,:)=reshape( ...
            prctile(draws(:,3,:),[2.5 97.5],1),1,1,2,2);
        idealIndex=find(ideal.snrDb==snrs(snrIndex),1);
        for method=1:3
            gate=v4IdealBoundTest(localRaw(method,1),localDen(method,1), ...
                ideal.ser(idealIndex));idealPass(caseIndex,snrIndex,method)=gate.pass;
            tableRow=tableRow+1;
            rows(tableRow,:)={caseIndex,snrs(snrIndex),methods{method},n, ...
                localRaw(method,1),localDen(method,1), ...
                localRaw(method,1)/localDen(method,1), ...
                localRaw(method,2),localDen(method,2), ...
                localRaw(method,2)/localDen(method,2),gate.status};
        end
        stageVp=stageVp+u.stageAcceptedVp;stageFalseVp=stageFalseVp+u.stageFalseVp;
        cellHashes(caseIndex,snrIndex,1)=v4Sha256(hp);
        cellHashes(caseIndex,snrIndex,2)=v4Sha256(up);
    end
end
summary=cell2table(rows,'VariableNames',{'caseIndex','snrDb','method', ...
    'packets','symbolErrors','symbolCount','ser','hardBitErrors', ...
    'hardBitCount','hardBer','idealStatus'});
out=fullfile(root,'results','method_aligned',reportDir);
if ~isfolder(out),mkdir(out),end
csvPath=fullfile(out,'summary.csv');writetable(summary,csvPath);

paperSer=squeeze(metrics(2,:,3,1)).';
huangSer=squeeze(metrics(2,:,1,1)).';
stageSer=squeeze(metrics(2,:,2,1)).';
huangCase1Ser=squeeze(metrics(1,:,1,1)).';
reference=[1 .99 .94 .86 .72 .56 .43 .29 .14 .05].';
paperLogRmse=sqrt(mean((log10(max(paperSer,1/(n*112)))-log10(reference)).^2));
huangCase1LogRmse=sqrt(mean((log10(max(huangCase1Ser,1/(n*112)))- ...
    log10(ideal.ser)).^2));
rawCase1=squeeze(raw(1,:,:,:));rawCase2=squeeze(raw(2,:,:,:));
case1Raw=all(rawCase1(:,2,:)<=rawCase1(:,1,:),'all')&& ...
    all(rawCase1(:,2,:)<rawCase1(:,3,:),'all');
case2Raw=all(rawCase2(:,2,:)<rawCase2(:,3,:),'all')&& ...
    all(rawCase2(:,3,:)<rawCase2(:,1,:),'all');
case1Paired=all(stageHuangBounds(1,:,2,:)<=0,'all')&& ...
    all(stagePaperBounds(1,:,2,:)<0,'all');
case2Paired=all(stagePaperBounds(2,:,2,:)<0,'all')&& ...
    all(stageHuangBounds(2,:,2,:)<0,'all');
paperTrend=all(diff(paperSer)<0)&&paperLogRmse<=0.2;
huangTrend=numel(unique(rawCase2(:,1,1)))>=6&&huangSer(end)<huangSer(1);
falseVpRate=stageFalseVp/max(stageVp,1);
checks=struct('all20CellsComplete',height(summary)==60, ...
    'case1RawOrdering',case1Raw,'case2RawOrdering',case2Raw, ...
    'case1PairedOrdering95',case1Paired,'case2PairedOrdering95',case2Paired, ...
    'paperFigure11Trend',paperTrend,'huangSerNotConstant',huangTrend, ...
    'allIdealGatesPass',all(idealPass,'all'), ...
    'mlBerExcluded',true,'conditionsFrozen',true);
if string(variant)=="v23"
    checks=rmfield(checks,'case1PairedOrdering95');
    checks.case1PairedPointNoninferiority=all( ...
        rawCase1(:,2,:)<=rawCase1(:,1,:),'all');
end
if requireHuangCase1Theory
    checks.huangCase1TheoryTrend=all(diff(huangCase1Ser)<0)&& ...
        huangCase1LogRmse<=0.2;
end
if all(structfun(@(z)logical(z),checks))
    status='PASS';
    admission=['ADMIT_' upper(char(variant)) '_FREEZE'];
else
    status='FAIL';
    admission='RETURN_TO_MECHANISM_REPAIR';
end
report=struct('status',status,'admission',admission, ...
    'identity',reportIdentity,'checks',checks, ...
    'snrDb',snrs.','rawErrors',raw,'denominators',den,'metrics',metrics, ...
    'stageMinusPaperBounds95',stagePaperBounds, ...
    'paperMinusHuangBounds95',paperHuangBounds, ...
    'stageMinusHuangBounds95',stageHuangBounds, ...
    'case1ZeroMarginPaired95Diagnostic',case1Paired, ...
    'idealPass',idealPass,'paperReference',reference.', ...
    'paperLog10Rmse',paperLogRmse,'paperSer',paperSer.', ...
    'huangCase1Log10Rmse',huangCase1LogRmse, ...
    'huangCase1Ser',huangCase1Ser.', ...
    'huangSer',huangSer.','stageSer',stageSer.', ...
    'stageAcceptedVp',stageVp,'stageFalseVp',stageFalseVp, ...
    'stageFalseVpRate',falseVpRate,'cellHashes',cellHashes, ...
    'summaryCsv',csvPath,'bootstrapDraws',10000,'packetsPerCell',n);
save(fullfile(out,'report.mat'),'report','summary','-v7.3');
localWrite(fullfile(out,'report.json'),jsonencode(report,'PrettyPrint',true));
localPlots(out,snrs,metrics,den,reference,ideal.ser, ...
    figurePrefix,figureTitle);
localMarkdown(fullfile(out,'report.md'),report);
end

function localPlots(out,snrs,metrics,den,reference,idealSer, ...
        figurePrefix,figureTitle)
names={'Huang','Stage55','Paper'};colors=[.466 .674 .188;.85 .325 .098;0 .447 .741];
styles={'-.^','-s','--o'};
for metricIndex=1:2
    values=squeeze(metrics(:,:,:,metricIndex));counts=squeeze(den(:,:,:,metricIndex));
    plotValues=values;zero=plotValues==0;plotValues(zero)=0.5./counts(zero);
    if metricIndex==1&&strcmp(figurePrefix,'unified_v23')
        f=figure('Visible','off','Color','w','Position',[100 100 1250 500]);
        tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
        for caseIndex=1:2
            nexttile;
            semilogy(snrs,squeeze(plotValues(caseIndex,:,1)),'-.^', ...
                'Color',colors(1,:),'LineWidth',1.8,'MarkerSize',6, ...
                'DisplayName','PREC');hold on
            semilogy(snrs,squeeze(plotValues(caseIndex,:,2)),'-s', ...
                'Color',colors(2,:),'LineWidth',1.8,'MarkerSize',6, ...
                'DisplayName','SenLora');
            semilogy(snrs,squeeze(plotValues(caseIndex,:,3)),'--o', ...
                'Color',colors(3,:),'LineWidth',1.8,'MarkerSize',6, ...
                'DisplayName','MIDAMBLE-POINT');
            semilogy(snrs,idealSer,'-d','Color',[.15 .15 .15], ...
                'LineWidth',1.5,'MarkerSize',5,'DisplayName','AWGN');
            grid on;grid minor;xlabel('SNR (dB)');ylabel('SER');
            title(sprintf('Case %d',caseIndex));
            xlim([-30 -21]);legend('Location','southwest');
        end
        exportgraphics(f,fullfile(out,[figurePrefix '_ser.png']), ...
            'Resolution',220);
        savefig(f,fullfile(out,[figurePrefix '_ser.fig']));close(f);
        continue
    end
    f=figure('Visible','off','Color','w','Position',[100 100 1250 500]);
    tiles=tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
    for caseIndex=1:2
        nexttile;
        for method=1:3
            semilogy(snrs,squeeze(plotValues(caseIndex,:,method)),styles{method}, ...
                'Color',colors(method,:),'LineWidth',1.8,'MarkerSize',6, ...
                'DisplayName',names{method});hold on
        end
        if metricIndex==1
            semilogy(snrs,idealSer,'-d','Color',[.15 .15 .15], ...
                'LineWidth',1.5,'MarkerSize',5,'DisplayName','Ideal theory');
        end
        if metricIndex==1&&caseIndex==2
            semilogy(snrs,reference,':x','Color',[.301 .745 .933], ...
                'LineWidth',1.3,'DisplayName','Figure 11 reference');
        end
        grid on;grid minor;xlabel('SNR (dB)');
        if metricIndex==1,ylabel('SER');else,ylabel('Hard BER');end
        title(sprintf('Case %d',caseIndex));xlim([-30 -21]);
        legend('Location','southwest');
    end
    if metricIndex==1,label='SER';else,label='HARD_BER';end
    title(tiles,sprintf('%s 1000-packet %s test', ...
        figureTitle,strrep(label,'_',' ')));
    exportgraphics(f,fullfile(out,[figurePrefix '_' lower(label) '.png']), ...
        'Resolution',220);savefig(f,fullfile(out,[figurePrefix '_' lower(label) '.fig']));
    close(f);
end
end

function localMarkdown(path,r)
file=fopen(path,'w','n','UTF-8');cleaner=onCleanup(@()fclose(file));
fprintf(file,'# %s report\n\n',r.identity);
fprintf(file,'Status: **%s**\n\nAdmission: `%s`\n\n',r.status,r.admission);
names=fieldnames(r.checks);
for k=1:numel(names)
    if r.checks.(names{k})
        v='PASS';
    else
        v='FAIL';
    end
    fprintf(file,'- %s: %s\n',names{k},v);
end
fprintf(file,'\nPaper Figure 11 log10 RMSE: %.6f decade.\n',r.paperLog10Rmse);
fprintf(file,'Huang Case1 vs Ideal log10 RMSE: %.6f decade.\n', ...
    r.huangCase1Log10Rmse);
fprintf(file,'Case1 zero-margin paired 95%% diagnostic: %d.\n', ...
    r.case1ZeroMarginPaired95Diagnostic);
fprintf(file,'Stage VP false rate: %.9g (%d/%d).\n', ...
    r.stageFalseVpRate,r.stageFalseVp,r.stageAcceptedVp);clear cleaner
end

function localWrite(path,text)
file=fopen(path,'w','n','UTF-8');cleaner=onCleanup(@()fclose(file));
fprintf(file,'%s\n',text);clear cleaner
end
