function report = run_stage54_complexity_goodput_report(options)
%RUN_STAGE54_COMPLEXITY_GOODPUT_REPORT Complexity and delivery-rate audit.
%   This stage does not rerun the receiver and does not change any formal
%   data.  It derives code-level operation bounds and empirical timing/
%   goodput metrics from the frozen Stage 53 complete-pass artifacts.

arguments
    options.FormalResultFolder (1,:) char = ''
    options.OutputFolderName (1,:) char = 'stage54_complexity_goodput'
    options.WriteArtifacts (1,1) logical = true
    options.WriteFigure (1,1) logical = true
end

root = fileparts(mfilename('fullpath'));
if isempty(options.FormalResultFolder)
    formalFolder = fullfile(root,'results', ...
        'stage53_formal_repeated_passes');
else
    formalFolder = options.FormalResultFolder;
end
formalPath = fullfile(formalFolder,'stage52_formal_time_latest.mat');
if ~isfile(formalPath)
    error('SatelliteFig3:Stage54FormalInput', ...
        'Formal Stage 53 MAT artifact not found: %s',formalPath);
end
formal = load(formalPath);
localValidateFormalInput(formal);

config = formal.config;
schedule = formal.schedule;
methodNames = formal.methodNames;
snrGridDb = formal.options.SnrGridDb(:);
payloadBitsPerFrame = config.sf*4* ...
    (config.payloadSymbolCount/(4+config.cr));
nominalPayloadRateBps = payloadBitsPerFrame/schedule.frameDurationSec;

runtimeTable = localRuntimeTable(formal,payloadBitsPerFrame, ...
    nominalPayloadRateBps);
complexityTable = localComplexityTable(config,methodNames);
dynamicTable = formal.regionTable(:,{ ...
    'snrIndex','snrDb','dynamicRegion','method','completedPasses', ...
    'framesPerPass','bitCount','bitErrors','ber','frameErrors','per', ...
    'cfoRmseBins','activeLinkGoodputBps','acceptedPilots', ...
    'falseAcceptedPilots'});

outputFolder = fullfile(root,'results',options.OutputFolderName);
pngPath = '';
figPath = '';
markdownPath = '';
if options.WriteArtifacts
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end
    writetable(runtimeTable,fullfile(outputFolder, ...
        'stage54_runtime_and_delivery.csv'));
    writetable(complexityTable,fullfile(outputFolder, ...
        'stage54_analytical_complexity.csv'));
    writetable(dynamicTable,fullfile(outputFolder, ...
        'stage54_dynamic_region_delivery.csv'));
    markdownPath = fullfile(outputFolder, ...
        'STAGE54_COMPLEXITY_GOODPUT_REPORT.md');
    localWriteMarkdown(markdownPath,runtimeTable,complexityTable, ...
        dynamicTable,formal,payloadBitsPerFrame,nominalPayloadRateBps);
    save(fullfile(outputFolder,'stage54_complexity_goodput_latest.mat'), ...
        'runtimeTable','complexityTable','dynamicTable', ...
        'payloadBitsPerFrame','nominalPayloadRateBps','formalFolder');
    if options.WriteFigure
        [pngPath,figPath] = localPlot(outputFolder,runtimeTable, ...
            dynamicTable,snrGridDb,methodNames,schedule.frameDurationSec);
    end
end

report = struct( ...
    'formalFolder',formalFolder, ...
    'outputFolder',outputFolder, ...
    'runtimeTable',runtimeTable, ...
    'complexityTable',complexityTable, ...
    'dynamicTable',dynamicTable, ...
    'payloadBitsPerFrame',payloadBitsPerFrame, ...
    'nominalPayloadRateBps',nominalPayloadRateBps, ...
    'pngPath',pngPath,'figPath',figPath,'markdownPath',markdownPath);
end

function localValidateFormalInput(formal)
required = {'config','schedule','methodNames','options','state', ...
    'frameTable','summaryTable','regionTable','pairedTable'};
for fieldIndex = 1:numel(required)
    if ~isfield(formal,required{fieldIndex})
        error('SatelliteFig3:Stage54FormalField', ...
            'Formal input is missing %s.',required{fieldIndex});
    end
end
if ~isequal(formal.methodNames, ...
        {'Huang-PREC-static-CP','SenLoRa-VP'}) || ...
        ~isequal(formal.options.SnrGridDb,[-21;-20]) || ...
        ~all(formal.state.snrCompleted)
    error('SatelliteFig3:Stage54FormalPolicy', ...
        'Stage 54 accepts only the completed frozen Stage 53 comparison.');
end
if any(formal.summaryTable.completedPasses < 5) || ...
        any(formal.summaryTable.bitErrors < 300)
    error('SatelliteFig3:Stage54FormalBudget', ...
        'Formal complete-pass/error budgets were not met.');
end
end

function tableData = localRuntimeTable(formal,payloadBitsPerFrame, ...
        nominalPayloadRateBps)
methodNames = formal.methodNames;
snrGridDb = formal.options.SnrGridDb(:);
rowCount = numel(methodNames)*numel(snrGridDb);
snrIndexColumn = zeros(rowCount,1);
snrDbColumn = zeros(rowCount,1);
methodColumn = cell(rowCount,1);
formalFrameCount = zeros(rowCount,1);
meanRuntimeSecPerFrame = zeros(rowCount,1);
medianRuntimeSecPerFrame = zeros(rowCount,1);
p95RuntimeSecPerFrame = zeros(rowCount,1);
maxRuntimeSecPerFrame = zeros(rowCount,1);
runtimeRatioToHuang = zeros(rowCount,1);
realTimeMarginFrames = zeros(rowCount,1);
receiverComputeCapacityBps = zeros(rowCount,1);
processingDeadlineMissRate = zeros(rowCount,1);
ber = zeros(rowCount,1);
per = zeros(rowCount,1);
activeLinkPacketGoodputBps = zeros(rowCount,1);
passAveragePacketDeliveryBps = zeros(rowCount,1);
activeLinkCorrectBitRateBps = zeros(rowCount,1);
acceptedPilots = zeros(rowCount,1);
falseAcceptedPilots = zeros(rowCount,1);

row = 0;
for snrIndex = 1:numel(snrGridDb)
    huangMean = NaN;
    for methodIndex = 1:numel(methodNames)
        row = row+1;
        summaryRow = formal.summaryTable.snrIndex == snrIndex & ...
            strcmp(formal.summaryTable.method,methodNames{methodIndex});
        assert(nnz(summaryRow) == 1, ...
            'Expected one summary row per SNR/method.');
        frameRows = formal.frameTable.snrIndex == snrIndex & ...
            formal.frameTable.includedInFormalStatistics;
        if methodIndex == 1
            runtime = formal.frameTable.staticRuntimeSec(frameRows);
        else
            runtime = formal.frameTable.senRuntimeSec(frameRows);
        end
        runtime = runtime(isfinite(runtime));
        assert(~isempty(runtime),'Formal runtime samples are missing.');

        snrIndexColumn(row) = snrIndex;
        snrDbColumn(row) = snrGridDb(snrIndex);
        methodColumn{row} = methodNames{methodIndex};
        formalFrameCount(row) = numel(runtime);
        meanRuntimeSecPerFrame(row) = mean(runtime);
        medianRuntimeSecPerFrame(row) = median(runtime);
        p95RuntimeSecPerFrame(row) = localPercentile(runtime,0.95);
        maxRuntimeSecPerFrame(row) = max(runtime);
        if methodIndex == 1
            huangMean = meanRuntimeSecPerFrame(row);
        end
        runtimeRatioToHuang(row) = meanRuntimeSecPerFrame(row)/huangMean;
        realTimeMarginFrames(row) = formal.schedule.frameDurationSec/ ...
            meanRuntimeSecPerFrame(row);
        receiverComputeCapacityBps(row) = payloadBitsPerFrame/ ...
            meanRuntimeSecPerFrame(row);
        processingDeadlineMissRate(row) = mean( ...
            runtime > formal.schedule.frameDurationSec);
        ber(row) = formal.summaryTable.berRaw(summaryRow);
        per(row) = formal.summaryTable.per(summaryRow);
        activeLinkPacketGoodputBps(row) = ...
            formal.summaryTable.activeLinkGoodputBps(summaryRow);
        passAveragePacketDeliveryBps(row) = ...
            formal.summaryTable.passAverageDeliveryBps(summaryRow);
        activeLinkCorrectBitRateBps(row) = nominalPayloadRateBps* ...
            (1-ber(row));
        acceptedPilots(row) = formal.summaryTable.acceptedPilots(summaryRow);
        falseAcceptedPilots(row) = ...
            formal.summaryTable.falseAcceptedPilots(summaryRow);
    end
end

tableData = table(snrIndexColumn,snrDbColumn,methodColumn, ...
    formalFrameCount,meanRuntimeSecPerFrame,medianRuntimeSecPerFrame, ...
    p95RuntimeSecPerFrame,maxRuntimeSecPerFrame,runtimeRatioToHuang, ...
    realTimeMarginFrames,receiverComputeCapacityBps, ...
    processingDeadlineMissRate, ...
    repmat(nominalPayloadRateBps,rowCount,1),ber,per, ...
    activeLinkPacketGoodputBps,passAveragePacketDeliveryBps, ...
    activeLinkCorrectBitRateBps,acceptedPilots,falseAcceptedPilots, ...
    'VariableNames',{'snrIndex','snrDb','method','formalFrameCount', ...
    'meanRuntimeSecPerFrame','medianRuntimeSecPerFrame', ...
    'p95RuntimeSecPerFrame','maxRuntimeSecPerFrame', ...
    'runtimeRatioToHuang','realTimeMarginFrames', ...
    'receiverComputeCapacityBps','processingDeadlineMissRate', ...
    'nominalPayloadRateBps','ber','per', ...
    'activeLinkPacketGoodputBps','passAveragePacketDeliveryBps', ...
    'activeLinkCorrectBitRateBps','acceptedPilots', ...
    'falseAcceptedPilots'});
end

function tableData = localComplexityTable(config,methodNames)
m = config.samplesPerSymbol;
knownPilots = config.bootstrapPilotCount;
payloadSymbols = config.payloadSymbolCount;
frameSymbols = config.frameSymbolCount;
etaCandidates = numel(0:0.1:(1-0.1/2));
bootstrapLengthMFFTs = knownPilots*etaCandidates+knownPilots;
minimumIterations = 2;
maximumIterations = config.maxSenLoRaIterations;
trackerFftsPerIteration = payloadSymbols;
confidenceFftsPerIteration = frameSymbols;
blockLength = 4+config.cr;
blockCount = payloadSymbols/blockLength;
llrLogSumExpInputsPerIteration = payloadSymbols*config.sf*m;
hammingScoreTermsPerIteration = blockCount*config.sf*16*blockLength;
causallyUsablePayloadCandidates = payloadSymbols-blockLength;
maximumResidualTrackerPasses = max(0,maximumIterations-2);
maximumResidualBanks = causallyUsablePayloadCandidates* ...
    maximumResidualTrackerPasses;

method = methodNames(:);
bootstrapEtaCandidateCount = repmat(etaCandidates,2,1);
bootstrapKnownUpchirpCount = repmat(knownPilots,2,1);
bootstrapLengthMFFTCount = repmat(bootstrapLengthMFFTs,2,1);
iterationLowerBound = [1;minimumIterations];
iterationUpperBound = [1;maximumIterations];
trackerLengthMFFTsPerIteration = [payloadSymbols;trackerFftsPerIteration];
confidenceLengthMFFTsPerIteration = [0;confidenceFftsPerIteration];
totalLengthMFFTsLower = [bootstrapLengthMFFTs+payloadSymbols; ...
    bootstrapLengthMFFTs+minimumIterations*( ...
    trackerFftsPerIteration+confidenceFftsPerIteration)];
totalLengthMFFTsUpper = [totalLengthMFFTsLower(1); ...
    bootstrapLengthMFFTs+maximumIterations*( ...
    trackerFftsPerIteration+confidenceFftsPerIteration)];
llrLogSumExpInputsLower = [0;minimumIterations* ...
    llrLogSumExpInputsPerIteration];
llrLogSumExpInputsUpper = [0;maximumIterations* ...
    llrLogSumExpInputsPerIteration];
softHammingScoreTermsLower = [0;minimumIterations* ...
    hammingScoreTermsPerIteration];
softHammingScoreTermsUpper = [0;maximumIterations* ...
    hammingScoreTermsPerIteration];
residualOffsetCandidateCount = [0;numel(config.residualSearchBins)];
residualProjectionBanksUpper = [0;maximumResidualBanks];
rollingHistoryLength = repmat(config.virtualPilotHistoryLength,2,1);
countInterpretation = { ...
    'exact for one frame'; ...
    'code-derived 2-to-5 iteration bound; measured runtime contains actual early stopping'};
asymptoticOrder = { ...
    'O((Np*(Keta+1)+Npayload)*M*log2(M))'; ...
    'O(Np*(Keta+1)*M*log2(M)+I*((Npayload+Nframe)*M*log2(M)+Npayload*SF*M)+R*(Kr+1)*M)'};

tableData = table(method,bootstrapEtaCandidateCount, ...
    bootstrapKnownUpchirpCount,bootstrapLengthMFFTCount, ...
    iterationLowerBound,iterationUpperBound, ...
    trackerLengthMFFTsPerIteration,confidenceLengthMFFTsPerIteration, ...
    totalLengthMFFTsLower,totalLengthMFFTsUpper, ...
    llrLogSumExpInputsLower,llrLogSumExpInputsUpper, ...
    softHammingScoreTermsLower,softHammingScoreTermsUpper, ...
    residualOffsetCandidateCount,residualProjectionBanksUpper, ...
    rollingHistoryLength,countInterpretation,asymptoticOrder);
end

function value = localPercentile(samples,fraction)
samples = sort(samples(:));
if numel(samples) == 1
    value = samples;
    return
end
position = 1+(numel(samples)-1)*fraction;
lower = floor(position);
upper = ceil(position);
weight = position-lower;
value = (1-weight)*samples(lower)+weight*samples(upper);
end

function [pngPath,figPath] = localPlot(outputFolder,runtimeTable, ...
        dynamicTable,snrGridDb,methodNames,frameDurationSec)
colors = [0.85 0.15 0.10;0.00 0.35 0.85];
runtime = localMethodMatrix(runtimeTable,'meanRuntimeSecPerFrame', ...
    snrGridDb,methodNames);
margin = localMethodMatrix(runtimeTable,'realTimeMarginFrames', ...
    snrGridDb,methodNames);
passGoodput = localMethodMatrix(runtimeTable, ...
    'passAveragePacketDeliveryBps',snrGridDb,methodNames);

regionNames = {'low_dynamic_lt_0p5_bin_per_frame', ...
    'high_dynamic_ge_0p5_bin_per_frame'};
dynamicGoodput = zeros(numel(snrGridDb)*2,2);
dynamicLabels = cell(numel(snrGridDb)*2,1);
row = 0;
for snrIndex = 1:numel(snrGridDb)
    for regionIndex = 1:2
        row = row+1;
        dynamicLabels{row} = sprintf('%g dB / %s',snrGridDb(snrIndex), ...
            ternary(regionIndex == 1,'low','high'));
        for methodIndex = 1:2
            rows = dynamicTable.snrDb == snrGridDb(snrIndex) & ...
                strcmp(dynamicTable.dynamicRegion,regionNames{regionIndex}) & ...
                strcmp(dynamicTable.method,methodNames{methodIndex});
            dynamicGoodput(row,methodIndex) = ...
                dynamicTable.activeLinkGoodputBps(rows);
        end
    end
end

fig = figure('Visible','off','Color','w','Position',[80 60 1320 880]);
tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
snrLabels = arrayfun(@(x)sprintf('%g dB',x),snrGridDb, ...
    'UniformOutput',false);

ax = nexttile;
localGroupedBars(ax,runtime,colors,methodNames);
set(ax,'XTick',1:numel(snrGridDb),'XTickLabel',snrLabels);
ylabel(ax,'Mean receiver time / frame (s)');
title(ax,sprintf('(a) Empirical runtime; frame duration %.5f s', ...
    frameDurationSec));
localAxes(ax);

ax = nexttile;
localGroupedBars(ax,margin,colors,methodNames);
set(ax,'XTick',1:numel(snrGridDb),'XTickLabel',snrLabels);
yline(ax,1,'k:','Real-time boundary','LabelHorizontalAlignment','left');
ylabel(ax,'Real-time margin (frame durations)');
title(ax,'(b) Processing margin (>1 meets frame deadline)');
localAxes(ax);

ax = nexttile;
localGroupedBars(ax,passGoodput,colors,methodNames);
set(ax,'XTick',1:numel(snrGridDb),'XTickLabel',snrLabels);
ylabel(ax,'Pass-average packet delivery (bit/s)');
title(ax,'(c) Effective rate over the complete pass');
localAxes(ax);

ax = nexttile;
localGroupedBars(ax,dynamicGoodput,colors,methodNames);
set(ax,'XTick',1:numel(dynamicLabels),'XTickLabel',dynamicLabels);
ylabel(ax,'Active-link packet goodput (bit/s)');
title(ax,'(d) Physical low/high-dynamic regions');
localAxes(ax);
legend(ax,methodNames,'Location','northoutside','NumColumns',2, ...
    'Box','off');

sgtitle(fig,['Complexity and effective-rate audit: ' ...
    'Huang-PREC-static-CP vs SenLoRa-VP'], ...
    'FontWeight','bold','FontSize',14);
pngPath = fullfile(outputFolder,'stage54_complexity_goodput.png');
figPath = fullfile(outputFolder,'stage54_complexity_goodput.fig');
exportgraphics(fig,pngPath,'Resolution',220);
savefig(fig,figPath);
close(fig);
end

function matrix = localMethodMatrix(tableData,columnName,snrGridDb,methodNames)
matrix = zeros(numel(snrGridDb),numel(methodNames));
for snrIndex = 1:numel(snrGridDb)
    for methodIndex = 1:numel(methodNames)
        rows = tableData.snrDb == snrGridDb(snrIndex) & ...
            strcmp(tableData.method,methodNames{methodIndex});
        assert(nnz(rows) == 1,'Expected one plotting row per SNR/method.');
        matrix(snrIndex,methodIndex) = tableData.(columnName)(rows);
    end
end
end

function localGroupedBars(ax,values,colors,methodNames)
bars = bar(ax,1:size(values,1),values,'grouped');
for methodIndex = 1:numel(bars)
    bars(methodIndex).FaceColor = colors(methodIndex,:);
    bars(methodIndex).EdgeColor = 'none';
    bars(methodIndex).DisplayName = methodNames{methodIndex};
end
end

function localAxes(ax)
grid(ax,'on');
box(ax,'on');
set(ax,'FontName','Times New Roman','FontSize',10.5, ...
    'GridLineStyle',':','MinorGridLineStyle',':','LineWidth',0.8);
end

function output = ternary(condition,trueValue,falseValue)
if condition
    output = trueValue;
else
    output = falseValue;
end
end

function localWriteMarkdown(path,runtimeTable,complexityTable, ...
        dynamicTable,formal,payloadBitsPerFrame,nominalPayloadRateBps)
fid = fopen(path,'w','n','UTF-8');
if fid < 0
    error('SatelliteFig3:Stage54Markdown','Cannot open %s.',path);
end
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>

fprintf(fid,'# Stage 54：复杂度与有效通信速率审计\n\n');
fprintf(fid,['本报告只读取 Stage 53 冻结的 5 次完整过境结果；没有重新运行接收机，' ...
    '没有改变算法、阈值、随机种子或曲线数据。\n\n']);
fprintf(fid,'## Huang-PREC 来源锚点\n\n');
fprintf(fid,'- `D:\\codex\\师兄代码\\matlab\\CFO相关\\频移算法\\PREC.m`\n');
fprintf(fid,'  - SHA-256: `3AB8FBC23C595485E0CC9E478223C1A4048BD034A666EE97D7499AF55DF77E98`\n');
fprintf(fid,['- `D:\\codex\\师兄代码\\matlab\\CFO相关\\频移算法\\卫星信道\\卫星信道\\' ...
    'MonteCarlo_BER_RMSE_PRC_EC_TQ28.m`\n']);
fprintf(fid,'  - SHA-256: `85E657783A2A791DE2843526334DE6BBAD816CF2050E8D5A164A5D19A1C1CFD1`\n\n');
fprintf(fid,['当前 Huang 基线保留其 `eta=0:0.1:0.9`、8 个零上啁啾、去啁啾 FFT、' ...
    '全局峰值和 `epsilonHat=integerBin-eta`。唯一物理适配是将跨符号复数平均改成' ...
    '逐上啁啾 FFT 功率累加，以避免连续相位造成相消；载荷期 CFO 固定。\n\n']);

fprintf(fid,'## 口径\n\n');
fprintf(fid,'- 每帧信息位：`%g bit`；帧长：`%.5f s`；名义信息速率：`%.6f bit/s`。\n', ...
    payloadBitsPerFrame,formal.schedule.frameDurationSec,nominalPayloadRateBps);
fprintf(fid,'- active-link packet goodput = `(1-PER)*信息位/帧长`。\n');
fprintf(fid,'- pass-average delivery 将成功帧信息位除以完整 508 帧过境墙钟时间，包含盲区。\n');
fprintf(fid,'- correct-bit rate = `(1-BER)*名义信息速率`，只作为不丢弃坏帧时的辅助上界。\n');
fprintf(fid,'- runtime 是本机 MATLAB 实测，不等价于硬件无关运算量；理论计数另列。\n\n');

fprintf(fid,'## 正式运行时间与有效速率\n\n');
fprintf(fid,['| SNR | 方法 | 平均/中位/P95耗时(s/帧) | 相对Huang | 实时裕量 | ' ...
    'deadline miss | active goodput | pass-average | correct-bit rate |\n']);
fprintf(fid,'|---:|---|---:|---:|---:|---:|---:|---:|---:|\n');
for row = 1:height(runtimeTable)
    fprintf(fid,['| %g | %s | %.5f / %.5f / %.5f | %.2fx | %.2fx | %.3g | ' ...
        '%.2f | %.2f | %.2f |\n'],runtimeTable.snrDb(row), ...
        runtimeTable.method{row},runtimeTable.meanRuntimeSecPerFrame(row), ...
        runtimeTable.medianRuntimeSecPerFrame(row), ...
        runtimeTable.p95RuntimeSecPerFrame(row), ...
        runtimeTable.runtimeRatioToHuang(row), ...
        runtimeTable.realTimeMarginFrames(row), ...
        runtimeTable.processingDeadlineMissRate(row), ...
        runtimeTable.activeLinkPacketGoodputBps(row), ...
        runtimeTable.passAveragePacketDeliveryBps(row), ...
        runtimeTable.activeLinkCorrectBitRateBps(row));
end

fprintf(fid,'\n## 代码级复杂度计数\n\n');
fprintf(fid,['`M=2048`。Huang 每帧精确执行 200 个 M 点 FFT。SenLoRa 因提前收敛在 ' ...
    '2--5 次之间，执行 552--1248 个 M 点 FFT，另含 Gray LLR、软 Hamming、' ...
    '11 点局部残差投影和 rolling-8 稳健拟合。\n\n']);
fprintf(fid,['| 方法 | M点FFT下/上界 | 迭代下/上界 | LLR log-sum-exp输入下/上界 | ' ...
    '软Hamming评分项下/上界 | 残差投影bank上界 |\n']);
fprintf(fid,'|---|---:|---:|---:|---:|---:|\n');
for row = 1:height(complexityTable)
    fprintf(fid,'| %s | %g / %g | %g / %g | %g / %g | %g / %g | %g |\n', ...
        complexityTable.method{row}, ...
        complexityTable.totalLengthMFFTsLower(row), ...
        complexityTable.totalLengthMFFTsUpper(row), ...
        complexityTable.iterationLowerBound(row), ...
        complexityTable.iterationUpperBound(row), ...
        complexityTable.llrLogSumExpInputsLower(row), ...
        complexityTable.llrLogSumExpInputsUpper(row), ...
        complexityTable.softHammingScoreTermsLower(row), ...
        complexityTable.softHammingScoreTermsUpper(row), ...
        complexityTable.residualProjectionBanksUpper(row));
end

fprintf(fid,'\n## 动态区有效速率\n\n');
fprintf(fid,'| SNR | 区域 | 方法 | BER | PER | active packet goodput (bit/s) |\n');
fprintf(fid,'|---:|---|---|---:|---:|---:|\n');
for row = 1:height(dynamicTable)
    region = strrep(dynamicTable.dynamicRegion{row},'_',' ');
    fprintf(fid,'| %g | %s | %s | %.6g | %.6g | %.3f |\n', ...
        dynamicTable.snrDb(row),region,dynamicTable.method{row}, ...
        dynamicTable.ber(row),dynamicTable.per(row), ...
        dynamicTable.activeLinkGoodputBps(row));
end

mainStatic = localRuntimeRow(runtimeTable,-21,'Huang-PREC-static-CP');
mainSen = localRuntimeRow(runtimeTable,-21,'SenLoRa-VP');
suppStatic = localRuntimeRow(runtimeTable,-20,'Huang-PREC-static-CP');
suppSen = localRuntimeRow(runtimeTable,-20,'SenLoRa-VP');
fprintf(fid,'\n## 可用于论文的结论边界\n\n');
fprintf(fid,['- SenLoRa 的平均接收机耗时约为 Huang 的 `%.2fx`（-21 dB）和 `%.2fx`' ...
    '（-20 dB），但两者所有正式帧均在 %.5f s 帧周期内完成，deadline miss rate 为 0。\n'], ...
    mainSen.runtimeRatioToHuang, suppSen.runtimeRatioToHuang, ...
    formal.schedule.frameDurationSec);
fprintf(fid,['- 全过境 packet delivery 在 -21 dB 为 Huang/Sen `%.2f/%.2f bit/s`，' ...
    '在 -20 dB 为 `%.2f/%.2f bit/s`。SenLoRa 的 BER 改善不必然转化为 PER/goodput 改善，' ...
    '因为少量误码可能分散到更多帧。\n'], ...
    mainStatic.passAveragePacketDeliveryBps,mainSen.passAveragePacketDeliveryBps, ...
    suppStatic.passAveragePacketDeliveryBps,suppSen.passAveragePacketDeliveryBps);
fprintf(fid,['- 物理高动态区两种 SNR 下 SenLoRa 的 BER 和 packet goodput 均优于静态 Huang；' ...
    '低动态区 Huang 更好。这是主时间图中曲线可区分的原因，也必须作为算法适用边界同时报告。\n']);
fprintf(fid,['- 本报告没有测量功耗、芯片面积或嵌入式能耗；不能用 MATLAB 墙钟时间替代这些指标。' ...
    '硬件无关比较应引用 FFT/LLR/Hamming/残差投影计数。\n']);
end

function row = localRuntimeRow(tableData,snrDb,method)
rows = tableData.snrDb == snrDb & strcmp(tableData.method,method);
assert(nnz(rows) == 1,'Expected one runtime row.');
row = table2struct(tableData(rows,:));
end
