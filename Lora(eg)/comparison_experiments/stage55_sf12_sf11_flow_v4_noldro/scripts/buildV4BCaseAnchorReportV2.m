function report = buildV4BCaseAnchorReportV2(variant)
%BUILDV4BCASEANCHORREPORTV2 Aggregate V5 paired cells and draw SER/BER.
if nargin < 1,variant = 'v2';end
switch lower(variant)
    case 'v2'
        dataIdentity = 'B-case-anchor-AWGN-v2-joint-preamble';
        planVersion = 'B-case-anchor-AWGN-v2';
        algorithmVersion = 'Stage55-B-case-anchor-joint-preamble-v5';
        paperAlgorithmVersion = 'legacy-paper-adaptation';
        fileStem = 'B_CASE_ANCHOR_AWGN_V2';
        bootstrapSeedRoot = 591000000;
        snrs = (-30:-21).';
    case 'v3'
        dataIdentity = 'B-case-anchor-AWGN-v3-CFO-regime';
        planVersion = 'B-case-anchor-AWGN-v3';
        algorithmVersion = 'Stage55-B-case-anchor-CFO-regime-v6';
        paperAlgorithmVersion = 'legacy-paper-adaptation';
        fileStem = 'B_CASE_ANCHOR_AWGN_V3';
        bootstrapSeedRoot = 596000000;
        snrs = (-30:-21).';
    case 'v4'
        dataIdentity = 'B-case-anchor-AWGN-v4-paper-native-extended';
        planVersion = 'B-case-anchor-AWGN-v4';
        algorithmVersion = 'Stage55-B-case-anchor-CFO-regime-v6';
        paperAlgorithmVersion = 'Paper-Midamble-Point-integer-full-FFT-v2';
        fileStem = 'B_CASE_ANCHOR_AWGN_V4';
        bootstrapSeedRoot = 601000000;
        snrs = (-30:-15).';
    case 'v5'
        dataIdentity = 'B-case-anchor-AWGN-v5-robust-regime-paper-native';
        planVersion = 'B-case-anchor-AWGN-v5';
        algorithmVersion = 'Stage55-B-case-anchor-robust-regime-v7';
        paperAlgorithmVersion = 'Paper-Midamble-Point-integer-full-FFT-v2';
        fileStem = 'B_CASE_ANCHOR_AWGN_V5';
        bootstrapSeedRoot = 605000000;
        snrs = (-30:-15).';
    case 'v6'
        dataIdentity = 'B-case-anchor-AWGN-v6-known-case-profile';
        planVersion = 'B-case-anchor-AWGN-v6';
        algorithmVersion = 'Stage55-B-known-case-profile-v8';
        paperAlgorithmVersion = 'Paper-Midamble-Point-integer-full-FFT-v2';
        fileStem = 'B_CASE_ANCHOR_AWGN_V6';
        bootstrapSeedRoot = 609000000;
        snrs = (-30:-15).';
    otherwise
        error('V4:BCaseAnchorReportVariant','Unknown report variant %s.',variant);
end

root = v4SetupPaths();
nSnr = numel(snrs);
cases = [-366 0];
methods = {'Huang','Stage55','Paper'};
metrics = zeros(2,nSnr,3,4);
raw = zeros(2,nSnr,3,4);
denominators = zeros(2,nSnr,3,4);
staticFallbackCount = zeros(2,nSnr);
rateMean = zeros(2,nSnr);
rateStd = zeros(2,nSnr);
packetCells = cell(2,nSnr);
sourceHashes = strings(2,nSnr);
summaryRows = cell(2*nSnr*3,19);
row = 0;
for caseIndex = 1:2
    for snrIndex = 1:nSnr
        path = fullfile(root,'results','case_anchor_b', ...
            dataIdentity, ...
            sprintf('case_%d',caseIndex), ...
            sprintf('snr_%+03d',snrs(snrIndex)),'formal_cell.mat');
        if ~isfile(path)
            error('V4:BCaseAnchorReportV2', ...
                'Missing Case %d SNR %g.',caseIndex,snrs(snrIndex));
        end
        loaded = load(path,'cellResult');
        result = loaded.cellResult;
        metrics(caseIndex,snrIndex,:,:) = reshape(result.metrics,1,1,3,4);
        raw(caseIndex,snrIndex,:,:) = reshape(result.rawErrors,1,1,3,4);
        denominators(caseIndex,snrIndex,:,:) = ...
            reshape(result.denominators,1,1,3,4);
        staticFallbackCount(caseIndex,snrIndex) = result.staticFallbackCount;
        rateMean(caseIndex,snrIndex) = result.observableRateMeanBinsPerSec;
        rateStd(caseIndex,snrIndex) = result.observableRateStdBinsPerSec;
        packetCells{caseIndex,snrIndex} = double(result.packetErrors);
        sourceHashes(caseIndex,snrIndex) = result.sourceHash;
        for method = 1:3
            row = row+1;
            summaryRows(row,:) = {caseIndex,cases(caseIndex),snrs(snrIndex), ...
                methods{method},result.fixedPackets,result.initialCfoHz, ...
                result.initialCfoBins,result.initialRateHzPerSec, ...
                result.initialRateBinsPerSec,result.staticFallbackCount, ...
                result.observableRateMeanBinsPerSec, ...
                result.observableRateStdBinsPerSec, ...
                result.rawErrors(method,1),result.denominators(method,1), ...
                result.metrics(method,1),result.rawErrors(method,2), ...
                result.metrics(method,2),result.rawErrors(method,3), ...
                result.metrics(method,3)};
        end
    end
end
if numel(unique(sourceHashes)) ~= 1
    error('V4:BCaseAnchorSourceHash','Cell source hashes are inconsistent.');
end

summary = cell2table(summaryRows,'VariableNames', { ...
    'caseIndex','caseStartTimeSec','snrDb','method','pairedPackets', ...
    'initialCfoHz','initialCfoBins','initialRateHzPerSec', ...
    'initialRateBinsPerSec','staticFallbackCount', ...
    'observableRateMeanBinsPerSec','observableRateStdBinsPerSec', ...
    'symbolErrors','symbolCount','ser','hardBitErrors','hardBer', ...
    'mlBitErrors','mlBer'});
if any(strcmpi(variant,{'v4','v5','v6'}))
    gate = v4BCaseAnchorExtendedAdmissionV4(raw,denominators);
else
    gate = v4BCaseAnchorAdmissionV2(raw);
end
regimePass = all(staticFallbackCount(1,:) == 200) && ...
    all(staticFallbackCount(2,:) == 0);

bootstrapDraws = 10000;
% comparison order: Stage-Paper, Stage-Huang; metric: SER, hard, ML.
bounds = zeros(2,nSnr,2,3,2);
for caseIndex = 1:2
    for snrIndex = 1:nSnr
        packet = packetCells{caseIndex,snrIndex};
        normalizer = reshape([112 768 768 1],1,1,4);
        perPacket = packet./normalizer;
        key = struct('planVersion',planVersion, ...
            'phase','paired-bootstrap','track','B-case-anchor', ...
            'channel','AWGN','comparisonMode','case-anchor-controlled', ...
            'snrDb',snrs(snrIndex),'replicateId',caseIndex, ...
            'packetId',0,'eventType','paired-packet-bootstrap', ...
            'eventIndex',snrIndex,'sampleIndex',0,'component','resample');
        stream = RandStream('mt19937ar','Seed', ...
            v4KeyedSeed(bootstrapSeedRoot,key));
        draws = zeros(bootstrapDraws,2,3);
        for draw = 1:bootstrapDraws
            indices = randi(stream,200,200,1);
            sample = squeeze(mean(perPacket(indices,:,:),1));
            draws(draw,1,:) = sample(2,1:3)-sample(3,1:3);
            draws(draw,2,:) = sample(2,1:3)-sample(1,1:3);
        end
        q = prctile(draws,[2.5 97.5],1);
        bounds(caseIndex,snrIndex,:,:,:) = permute(q,[4 5 2 3 1]);
    end
end

out = fullfile(root,'results','reports');
if ~isfolder(out),mkdir(out),end
summaryCsv = fullfile(out,[fileStem '_SUMMARY.csv']);
writetable(summary,summaryCsv);

orderingRows = cell(2*nSnr*3,14);
row = 0;
metricNames = {'SER','hard-BER','ML-BER'};
for caseIndex = 1:2
    for snrIndex = 1:nSnr
        for metric = 1:3
            row = row+1;
            h = raw(caseIndex,snrIndex,1,metric);
            s = raw(caseIndex,snrIndex,2,metric);
            p = raw(caseIndex,snrIndex,3,metric);
            if caseIndex == 1
                pointPass = gate.case1NotWorseHuang(1,snrIndex,metric) && ...
                    gate.case1BetterPaperWithZeroFloor(1,snrIndex,metric);
            else
                pointPass = gate.case2StrictBetterBoth(1,snrIndex,metric);
            end
            orderingRows(row,:) = {caseIndex,snrs(snrIndex), ...
                metricNames{metric},h,s,p,pointPass, ...
                metrics(caseIndex,snrIndex,2,metric)- ...
                    metrics(caseIndex,snrIndex,3,metric), ...
                bounds(caseIndex,snrIndex,1,metric,1), ...
                bounds(caseIndex,snrIndex,1,metric,2), ...
                metrics(caseIndex,snrIndex,2,metric)- ...
                    metrics(caseIndex,snrIndex,1,metric), ...
                bounds(caseIndex,snrIndex,2,metric,1), ...
                bounds(caseIndex,snrIndex,2,metric,2), ...
                staticFallbackCount(caseIndex,snrIndex)};
        end
    end
end
ordering = cell2table(orderingRows,'VariableNames', { ...
    'caseIndex','snrDb','metric','huangErrors','stageErrors','paperErrors', ...
    'pointGatePass','stageMinusPaper','stageMinusPaperLower95', ...
    'stageMinusPaperUpper95','stageMinusHuang', ...
    'stageMinusHuangLower95','stageMinusHuangUpper95', ...
    'staticFallbackCount'});
orderingCsv = fullfile(out,[fileStem '_ORDERING.csv']);
writetable(ordering,orderingCsv);

plotMetrics = metrics;
zero = plotMetrics == 0;
plotMetrics(zero) = 0.5./denominators(zero);
plotOrder = [1 3 2];
colors = [.35 .35 .35;0 .447 .741;.85 .325 .098];
styles = {'-.^','--o','-s'};
display = {'Huang','Paper','Stage55'};
f = figure('Visible','off','Color','w','Position',[100 100 1200 480]);
tiles = tiledlayout(f,1,2,'TileSpacing','compact','Padding','compact');
for caseIndex = 1:2
    nexttile;
    for k = 1:3
        method = plotOrder(k);
        semilogy(snrs,squeeze(plotMetrics(caseIndex,:,method,1)), ...
            styles{k},'Color',colors(k,:),'LineWidth',1.8, ...
            'MarkerSize',6,'DisplayName',display{k});
        hold on
    end
    grid on; grid minor
    xlabel('SNR (dB)'); ylabel('SER');
    title(sprintf('Case %d: CFO %.1f bins, rate %.3f bins/s', ...
        caseIndex,summary.initialCfoBins(find(summary.caseIndex==caseIndex,1)), ...
        summary.initialRateBinsPerSec(find(summary.caseIndex==caseIndex,1))));
    xlim([snrs(1) snrs(end)]); ylim([1e-6 1.1]); legend('Location','southwest');
end
title(tiles,{sprintf('Case-anchor AWGN %s: SER',upper(variant)), ...
    '200 paired packets/SNR; zero errors shown at 0.5/N'},'FontWeight','bold');
serPng = fullfile(out,[fileStem '_SER.png']);
serFig = fullfile(out,[fileStem '_SER.fig']);
exportgraphics(f,serPng,'Resolution',220); savefig(f,serFig); close(f);

f = figure('Visible','off','Color','w','Position',[100 100 1200 850]);
tiles = tiledlayout(f,2,2,'TileSpacing','compact','Padding','compact');
berNames = {'Hard BER','ML BER'};
for caseIndex = 1:2
    for ber = 1:2
        nexttile((caseIndex-1)*2+ber);
        metric = ber+1;
        for k = 1:3
            method = plotOrder(k);
            semilogy(snrs,squeeze(plotMetrics(caseIndex,:,method,metric)), ...
                styles{k},'Color',colors(k,:),'LineWidth',1.8, ...
                'MarkerSize',6,'DisplayName',display{k});
            hold on
        end
        grid on; grid minor
        xlabel('SNR (dB)'); ylabel(berNames{ber});
        title(sprintf('Case %d - %s',caseIndex,berNames{ber}));
        xlim([snrs(1) snrs(end)]); ylim([1e-7 1]); legend('Location','southwest');
    end
end
title(tiles,{sprintf('Case-anchor AWGN %s: BER',upper(variant)), ...
    '200 paired packets/SNR; zero errors shown at 0.5/N'},'FontWeight','bold');
berPng = fullfile(out,[fileStem '_BER.png']);
berFig = fullfile(out,[fileStem '_BER.fig']);
exportgraphics(f,berPng,'Resolution',220); savefig(f,berFig); close(f);

if gate.overallPass && regimePass
    status = 'PASS';
else
    status = 'FAIL';
end
report = struct('status',status, ...
    'identity',dataIdentity, ...
    'algorithmVersion',algorithmVersion, ...
    'paperAlgorithmVersion',paperAlgorithmVersion, ...
    'usesKnownCaseProfile',strcmpi(variant,'v6'), ...
    'pairedPacketsPerCaseSnr',200,'bootstrapDraws',bootstrapDraws, ...
    'caseStartTimeSec',cases,'snrDb',snrs.', ...
    'metrics',metrics,'rawErrors',raw,'denominators',denominators, ...
    'admissionGate',gate,'regimePass',regimePass, ...
    'staticFallbackCount',staticFallbackCount, ...
    'observableRateMeanBinsPerSec',rateMean, ...
    'observableRateStdBinsPerSec',rateStd, ...
    'pairedDifferenceBounds95',bounds, ...
    'pairedDifferenceComparisonOrder',{{'Stage-Paper','Stage-Huang'}}, ...
    'metricOrder',{{'SER','hard-BER','ML-BER'}}, ...
    'sourceHash',char(sourceHashes(1,1)), ...
    'summaryCsv',summaryCsv,'orderingCsv',orderingCsv, ...
    'serPng',serPng,'berPng',berPng, ...
    'zeroErrorPlotConvention','0.5/N; raw tables retain exact zero', ...
    'conditionsFrozen',true,'selectionUsesTruth',false);
matPath = fullfile(out,[fileStem '_REPORT.mat']);
jsonPath = fullfile(out,[fileStem '_REPORT.json']);
mdPath = fullfile(out,[fileStem '_REPORT.md']);
save(matPath,'report','-v7.3');
localWrite(jsonPath,jsonencode(report,'PrettyPrint',true));
localWriteMarkdown(mdPath,report);
end

function localWrite(path,text)
file = fopen(path,'w','n','UTF-8');
cleaner = onCleanup(@()fclose(file));
fprintf(file,'%s\n',text);
clear cleaner
end

function localWriteMarkdown(path,report)
file = fopen(path,'w','n','UTF-8');
cleaner = onCleanup(@()fclose(file));
fprintf(file,'# %s report\n\n',report.identity);
fprintf(file,'Status: **%s**\n\n',report.status);
fprintf(file,'- Algorithm: `%s`\n',report.algorithmVersion);
fprintf(file,'- Paper algorithm: `%s`\n',report.paperAlgorithmVersion);
fprintf(file,'- Fixed sample: 200 paired packets per Case/SNR.\n');
fprintf(file,'- SNR: %g:%g dB; AWGN; CR3; 112 symbols; 768 information bits.\n', ...
    report.snrDb(1),report.snrDb(end));
fprintf(file,'- Case 1 rule: Stage <= Huang and Stage < Paper; when Paper has zero errors, Stage must also be zero.\n');
fprintf(file,'- Case 2 rule: Stage < Huang and Stage < Paper at every SNR for SER, hard BER and ML BER.\n');
fprintf(file,'- Case 1 pass: %d. Case 2 pass: %d. Regime gate pass: %d.\n', ...
    report.admissionGate.case1Pass,report.admissionGate.case2Pass, ...
    report.regimePass);
fprintf(file,'- Zero plot convention: 0.5/N for log display only; CSV/JSON preserve raw zero.\n');
fprintf(file,'- Selection uses payload/orbit truth: false.\n\n');
fprintf(file,'Artifacts:\n\n');
[~,name,ext] = fileparts(report.serPng);fprintf(file,'- `%s%s`\n',name,ext);
[~,name,ext] = fileparts(report.berPng);fprintf(file,'- `%s%s`\n',name,ext);
[~,name,ext] = fileparts(report.summaryCsv);fprintf(file,'- `%s%s`\n',name,ext);
[~,name,ext] = fileparts(report.orderingCsv);fprintf(file,'- `%s%s`\n',name,ext);
clear cleaner
end
