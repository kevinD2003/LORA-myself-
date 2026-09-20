function report = buildV4PaperCurveReportV7()
root = v4SetupPaths();snrs = (-30:-21).';methods = {'Huang','Stage55','Paper'};
raw = zeros(2,10,3,3);den = zeros(2,10,3,3);metrics = zeros(2,10,3,3);
paperPackets = cell(10,1);pairedPackets = cell(10,1);sourceHashes = strings(10,1);
parentReport = load(fullfile(root,'results','reports', ...
    'B_CASE_ANCHOR_AWGN_V6_REPORT.mat'),'report');
raw(1,:,:,:) = parentReport.report.rawErrors(1,1:10,:,1:3);
den(1,:,:,:) = parentReport.report.denominators(1,1:10,:,1:3);
metrics(1,:,:,:) = parentReport.report.metrics(1,1:10,:,1:3);
for snrIndex = 1:10
    parentPath = fullfile(root,'results','case_anchor_b', ...
        'B-case-anchor-AWGN-v6-known-case-profile','case_2', ...
        sprintf('snr_%+03d',snrs(snrIndex)),'formal_cell.mat');
    paperPath = fullfile(root,'results','paper_curve_v7','formal', ...
        sprintf('snr_%+03d',snrs(snrIndex)),'formal_cell.mat');
    a = load(parentPath,'cellResult');b = load(paperPath,'cellResult');
    parentPacket = double(a.cellResult.packetErrors(:,:,1:3));
    paperPacket = double(b.cellResult.packetErrors);
    packet = zeros(200,3,3);
    packet(:,1,:) = parentPacket(:,1,:);
    packet(:,2,:) = parentPacket(:,2,:);
    packet(:,3,:) = reshape(paperPacket,200,1,3);
    pairedPackets{snrIndex} = packet;paperPackets{snrIndex} = paperPacket;
    raw(2,snrIndex,:,:) = reshape(squeeze(sum(packet,1)),1,1,3,3);
    localDen = repmat([200*112 200*768 200*768],3,1);
    den(2,snrIndex,:,:) = reshape(localDen,1,1,3,3);
    metrics(2,snrIndex,:,:) = raw(2,snrIndex,:,:)./den(2,snrIndex,:,:);
    sourceHashes(snrIndex) = b.cellResult.sourceHash;
end
stage = squeeze(raw(2,:,2,:));huang = squeeze(raw(2,:,1,:));
paper = squeeze(raw(2,:,3,:));
strict = stage<huang & stage<paper;
paperSer = squeeze(metrics(2,:,3,1)).';
stageSer = squeeze(metrics(2,:,2,1)).';
referenceSer = [1 .99 .94 .86 .72 .56 .43 .29 .14 .05].';
logRmse = sqrt(mean((log10(max(paperSer,1/(200*112)))- ...
    log10(referenceSer)).^2));
curvePass = numel(unique(paper(:,1)))>=6 && paperSer(end)>=.02 && ...
    paperSer(end)<=.08 && logRmse<=.2;
parentCase1Pass = parentReport.report.admissionGate.case1Pass;
if all(strict,'all') && curvePass && parentCase1Pass,status='PASS';else,status='FAIL';end

bootstrapDraws = 10000;bounds = zeros(10,3,2);
for snrIndex = 1:10
    packet = pairedPackets{snrIndex};normalizer = reshape([112 768 768],1,1,3);
    perPacket = packet./normalizer;
    key = struct('planVersion','B-paper-curve-v7','phase','paired-bootstrap', ...
        'track','B-case-anchor','channel','AWGN', ...
        'comparisonMode','case-anchor-controlled','snrDb',snrs(snrIndex), ...
        'replicateId',1,'packetId',0,'eventType','paired-packet-bootstrap', ...
        'eventIndex',snrIndex,'sampleIndex',0,'component','resample');
    stream = RandStream('mt19937ar','Seed',v4KeyedSeed(622000000,key));
    draws = zeros(bootstrapDraws,3);
    for draw = 1:bootstrapDraws
        index = randi(stream,200,200,1);
        sample = squeeze(mean(perPacket(index,:,:),1));
        draws(draw,:) = sample(2,:)-sample(3,:);
    end
    bounds(snrIndex,:,1) = prctile(draws,2.5,1);
    bounds(snrIndex,:,2) = prctile(draws,97.5,1);
end

rows = cell(2*10*3,11);row = 0;
for caseIndex = 1:2
    for snrIndex = 1:10
        for method = 1:3
            row = row+1;
            rows(row,:) = {caseIndex,snrs(snrIndex),methods{method},200, ...
                raw(caseIndex,snrIndex,method,1), ...
                den(caseIndex,snrIndex,method,1), ...
                metrics(caseIndex,snrIndex,method,1), ...
                raw(caseIndex,snrIndex,method,2), ...
                metrics(caseIndex,snrIndex,method,2), ...
                raw(caseIndex,snrIndex,method,3), ...
                metrics(caseIndex,snrIndex,method,3)};
        end
    end
end
summary = cell2table(rows,'VariableNames',{'caseIndex','snrDb','method', ...
    'pairedPackets','symbolErrors','symbolCount','ser','hardBitErrors', ...
    'hardBer','mlBitErrors','mlBer'});
out = fullfile(root,'results','reports');
summaryCsv = fullfile(out,'B_CASE2_PAPER_FIG11_ALIGNED_V7_SUMMARY.csv');
writetable(summary,summaryCsv);

plotSer = squeeze(metrics(:,:,:,1));plotDen = squeeze(den(:,:,:,1));
zero = plotSer==0;plotSer(zero) = .5./plotDen(zero);
order = [1 3 2];colors = [.35 .35 .35;0 .447 .741;.85 .325 .098];
styles = {'-.^','--o','-s'};display = {'Huang','Paper','Stage55'};
f = figure('Visible','off','Color','w','Position',[100 100 1250 500]);
tiles = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
for caseIndex = 1:2
    nexttile;
    for k = 1:3
        method = order(k);
        semilogy(snrs,squeeze(plotSer(caseIndex,:,method)),styles{k}, ...
            'Color',colors(k,:),'LineWidth',1.8,'MarkerSize',6, ...
            'DisplayName',display{k});hold on
    end
    if caseIndex==2
        semilogy(snrs,referenceSer,':x','Color',[.301 .745 .933], ...
            'LineWidth',1.3,'MarkerSize',6, ...
            'DisplayName','Fig. 11 Midamble-Point reference (approx.)');
    end
    grid on;grid minor;xlabel('SNR (dB)');ylabel('SER');
    title(sprintf('Case %d',caseIndex));xlim([-30 -21]);ylim([1e-5 1.1]);
    legend('Location','southwest');
end
title(tiles,{'Case-anchor AWGN: Paper Figure 11 trend alignment', ...
    'Only Case 2 Paper changed; Stage55 and Case 1 reuse audited V6'}, ...
    'FontWeight','bold');
pngPath = fullfile(out,'B_CASE2_PAPER_FIG11_ALIGNED_V7_SER.png');
figPath = fullfile(out,'B_CASE2_PAPER_FIG11_ALIGNED_V7_SER.fig');
exportgraphics(f,pngPath,'Resolution',220);savefig(f,figPath);close(f);

report = struct('status',status,'identity','B-paper-curve-v7-formal', ...
    'paperAlgorithmVersion','Paper-Midamble-Point-local-trend-v5', ...
    'stageAlgorithmVersion','Stage55-B-known-case-profile-v8', ...
    'stage55Modified',false,'case1Modified',false, ...
    'case2PaperOnlyModified',true,'pairedPacketsPerSnr',200, ...
    'bootstrapDraws',bootstrapDraws,'snrDb',snrs.', ...
    'rawErrors',raw,'denominators',den,'metrics',metrics, ...
    'stageStrictBetterCase2AllMetrics',strict, ...
    'paperSer',paperSer,'referenceSerApproximate',referenceSer, ...
    'referenceLog10Rmse',logRmse,'paperCurvePass',curvePass, ...
    'parentCase1Pass',parentCase1Pass, ...
    'stageMinusPaperBounds95',bounds, ...
    'paperSourceHash',char(sourceHashes(1)), ...
    'singlePaperSourceHash',numel(unique(sourceHashes))==1, ...
    'parentIdentity','B-case-anchor-AWGN-v6-known-case-profile', ...
    'summaryCsv',summaryCsv,'serPng',pngPath,'serFig',figPath, ...
    'conditionsChanged',false,'zeroErrorPlotConvention','0.5/N');
save(fullfile(out,'B_CASE2_PAPER_FIG11_ALIGNED_V7_REPORT.mat'),'report','-v7.3');
localWrite(fullfile(out,'B_CASE2_PAPER_FIG11_ALIGNED_V7_REPORT.json'), ...
    jsonencode(report,'PrettyPrint',true));
localWriteMarkdown(fullfile(out,'B_CASE2_PAPER_FIG11_ALIGNED_V7_REPORT.md'),report);
end

function localWrite(path,text)
file=fopen(path,'w','n','UTF-8');cleaner=onCleanup(@()fclose(file));
fprintf(file,'%s\n',text);clear cleaner
end
function localWriteMarkdown(path,r)
file=fopen(path,'w','n','UTF-8');cleaner=onCleanup(@()fclose(file));
fprintf(file,'# Case 2 Paper Figure 11 aligned SER\n\nStatus: **%s**\n\n',r.status);
fprintf(file,'- Only Case 2 Paper changed; Stage55 and Case 1 are unchanged.\n');
fprintf(file,'- Paper: `%s`.\n',r.paperAlgorithmVersion);
fprintf(file,'- 200 paired packets/SNR, -30:-21 dB, 10000 paired bootstrap draws.\n');
fprintf(file,'- Figure 11 approximate log10 RMSE: %.6f decade.\n',r.referenceLog10Rmse);
fprintf(file,'- Case 2 Stage55 strictly better at every SNR for SER/hard BER/ML BER: %d.\n', ...
    all(r.stageStrictBetterCase2AllMetrics,'all'));
fprintf(file,'- Physical/statistical conditions changed: %d.\n',r.conditionsChanged);
clear cleaner
end
