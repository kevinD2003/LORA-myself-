function report = buildV3Report()
%BUILDV3REPORT Build formal tables, pass-paired intervals, plots, and report.

root = v3SetupPaths();
config = sf12Sf11FlowConfig();
[parameters,manifest] = v3LoadFrozenReceiverParameters(config); %#ok<ASGLU>
loaded = load(fullfile(root,'results','formal','v3_formal_comparison_v2.mat'),'formal');
formal = loaded.formal;
methods = string(config.methodNames);
regions = ["low-dynamic" "high-dynamic"];

summaryRows = cell(60,20);
cfoRows = cell(6720,7);
ciRows = cell(160,9);
summaryCounter = 0;
cfoCounter = 0;
ciCounter = 0;
stageTemplate = struct('vpAccepted',0,'vpFalse',0,'vpCoverage',0, ...
    'vpFalseRate',0,'firstMedian',NaN,'deadlineMisses',0,'fftCount',0);
stageExtras = repmat(stageTemplate,10,2);
for snrIndex = 1:numel(formal.points)
    point = formal.points{snrIndex};
    records = point.records;
    for regionIndex = 1:2
        for methodIndex = 1:3
            rows = records.region == regions(regionIndex) & ...
                records.methodName == methods(methodIndex);
            subset = records(rows,:);
            symbolErrors = sum(subset.symbolErrors);
            symbolCount = sum(subset.symbolCount);
            hardErrors = sum(subset.hardBitErrors);
            hardCount = sum(subset.hardBitCount);
            softErrors = sum(subset.softBitErrors);
            softCount = sum(subset.softBitCount);
            packetErrors = sum(subset.packetError);
            frameCount = height(subset);
            commonDuration = frameCount*config.commonTimelineSymbolCount* ...
                config.symbolDurationSec;
            if methodIndex == 3
                nativeFrameDuration = config.commonTimelineSymbolCount* ...
                    config.symbolDurationSec;
            else
                nativeFrameDuration = config.noMidambleFrameSymbolCount* ...
                    config.symbolDurationSec;
            end
            nativeDuration = frameCount*nativeFrameDuration;
            deliveredBits = (frameCount-packetErrors)*config.informationBitCount;
            vpAccepted = sum(subset.vpAccepted);
            vpFalse = sum(subset.vpFalseAccepted);
            first = subset.firstVpEffectivePhysicalRow;
            first = first(isfinite(first));
            if isempty(first), firstMedian = NaN; else, firstMedian = median(first); end
            summaryCounter = summaryCounter+1;
            summaryRows(summaryCounter,:) = {point.snrDb,regions(regionIndex), ...
                methods(methodIndex),point.completedPasses,frameCount, ...
                symbolErrors,symbolCount,symbolErrors/symbolCount, ...
                hardErrors,hardCount,hardErrors/hardCount, ...
                softErrors,softCount,softErrors/softCount, ...
                packetErrors,packetErrors/frameCount, ...
                sqrt(sum(subset.cfoSquaredErrorSum)/(frameCount*config.payloadSymbolCount)), ...
                deliveredBits/commonDuration,deliveredBits/nativeDuration, ...
                mean(subset.runtimeSec)};

            cfoSum = zeros(config.payloadSymbolCount,1);
            observationCount = 0;
            for pass = 1:point.completedPasses
                diagnostic = point.passDiagnostics(pass);
                cfoSum = cfoSum+squeeze( ...
                    diagnostic.symbolCfoSquaredErrorSum(methodIndex,regionIndex,:));
                observationCount = observationCount+ ...
                    diagnostic.symbolCfoObservationCount(methodIndex,regionIndex);
            end
            for symbol = 1:config.payloadSymbolCount
                cfoCounter = cfoCounter+1;
                cfoRows(cfoCounter,:) = {point.snrDb,regions(regionIndex), ...
                    methods(methodIndex),symbol,sqrt(cfoSum(symbol)/observationCount), ...
                    observationCount,config.fftBinSpacingHz};
            end

            if methodIndex == 2
                stageExtras(snrIndex,regionIndex) = struct( ...
                    'vpAccepted',vpAccepted,'vpFalse',vpFalse, ...
                    'vpCoverage',vpAccepted/(frameCount*config.payloadSymbolCount), ...
                    'vpFalseRate',vpFalse/max(vpAccepted,1), ...
                    'firstMedian',firstMedian, ...
                    'deadlineMisses',sum(subset.deadlineMiss), ...
                    'fftCount',sum(subset.fftCount));
            end
        end

        comparisons = [1 3];
        comparisonNames = ["Stage55 minus Huang" "Stage55 minus Paper-adapted"];
        for comparison = 1:2
            ciCounter = ciCounter+1;
            [passMetric,metricNames] = localPassMetrics(records,regions(regionIndex), ...
                methods,comparisons(comparison),config);
            stream = RandStream('mt19937ar','Seed', ...
                config.seeds.bootstrapResampleBase+ciCounter);
            for metric = 1:numel(metricNames)
                difference = passMetric(:,2,metric)-passMetric(:,1,metric);
                draws = zeros(2000,1);
                for draw = 1:2000
                    index = randi(stream,numel(difference),numel(difference),1);
                    draws(draw) = mean(difference(index));
                end
                ordered = sort(draws);
                lower = ordered(max(1,ceil(0.025*numel(ordered))));
                upper = ordered(min(numel(ordered),ceil(0.975*numel(ordered))));
                ciRow = (ciCounter-1)*numel(metricNames)+metric;
                ciRows(ciRow,:) = {point.snrDb,regions(regionIndex), ...
                    comparisonNames(comparison),metricNames(metric), ...
                    mean(difference),lower,upper,"complete-pass",2000};
            end
        end
    end
end

formalSummary = cell2table(summaryRows,'VariableNames',{ ...
    'snrDb','region','methodName','completePassCount','frameCount', ...
    'symbolErrors','symbolCount','ser','hardBitErrors','hardBitCount', ...
    'hardBer','softBitErrors','softBitCount','softBer','packetErrors', ...
    'per','cfoRmseBins','commonTimelineGoodputBps','nativeGoodputBps','meanRuntimeSec'});
symbolCfoRmse = cell2table(cfoRows,'VariableNames',{ ...
    'snrDb','region','methodName','payloadSymbolIndex','cfoRmseBins', ...
    'frameObservationCount','fftBinSpacingHz'});
pairedIntervals = cell2table(ciRows,'VariableNames',{ ...
    'snrDb','region','comparison','metric','meanDifference','lower95', ...
    'upper95','resamplingUnit','bootstrapDraws'});

complexity = groupsummary(formal.points{1}.records,'methodName','sum', ...
    {'fftCount','runtimeSec','deadlineMiss'});
paperOverhead = struct('midambleSymbols',config.paperMidambleCount, ...
    'noMidambleSymbols',config.noMidambleFrameSymbolCount, ...
    'commonTimelineSymbols',config.commonTimelineSymbolCount, ...
    'extraAirtimeFraction',config.paperMidambleCount/config.noMidambleFrameSymbolCount, ...
    'timelineFraction',config.paperMidambleCount/config.commonTimelineSymbolCount);
report = struct('algorithmSignature',manifest.algorithmSignature, ...
    'formalSummary',formalSummary,'symbolCfoRmse',symbolCfoRmse, ...
    'pairedIntervals',pairedIntervals,'paperOverhead',paperOverhead, ...
    'stage55Extras',stageExtras,'complexityExampleSnr',complexity, ...
    'paperIdentity','Paper-Midamble-Point-SF12-CR3-adapted', ...
    'isPaperFigureReplication',false);

output = fullfile(root,'results','reports');
save(fullfile(output,'v3_final_report_data.mat'),'report','-v7.3');
writetable(formalSummary,fullfile(output,'v3_formal_summary.csv'));
writetable(symbolCfoRmse,fullfile(output,'v3_symbol_cfo_rmse.csv'));
writetable(pairedIntervals,fullfile(output,'v3_paired_complete_pass_ci.csv'));
localPlots(formalSummary,methods,regions,output);
localWriteMarkdown(fullfile(output,'V3_FINAL_REPORT.md'),report,config);
end

function [passMetric,names] = localPassMetrics(records,region,methods,referenceMethod,config)
passes = unique(records.passIndexColumn);
passMetric = zeros(numel(passes),2,4);
selectedMethods = [referenceMethod 2];
for passIndex = 1:numel(passes)
    for side = 1:2
        rows = records.passIndexColumn == passes(passIndex) & ...
            records.region == region & records.methodName == methods(selectedMethods(side));
        subset = records(rows,:);
        passMetric(passIndex,side,1) = sum(subset.symbolErrors)/sum(subset.symbolCount);
        passMetric(passIndex,side,2) = sum(subset.softBitErrors)/sum(subset.softBitCount);
        passMetric(passIndex,side,3) = mean(subset.packetError);
        delivered = (height(subset)-sum(subset.packetError))*config.informationBitCount;
        duration = height(subset)*config.commonTimelineSymbolCount*config.symbolDurationSec;
        passMetric(passIndex,side,4) = delivered/duration;
    end
end
names = ["SER" "ML-soft-BER" "PER" "common-goodput-bps"];
end

function localPlots(summary,methods,regions,output)
metrics = {'ser','softBer','per','cfoRmseBins','commonTimelineGoodputBps'};
fileNames = {'ser_snr.png','soft_ber_snr.png','per_snr.png', ...
    'cfo_rmse_snr.png','goodput_snr.png'};
yLabels = {'SER','ML soft BER','PER','CFO RMSE (bin)','Goodput (bit/s)'};
for metricIndex = 1:numel(metrics)
    figureHandle = figure('Visible','off','Color','w');
    tiledlayout(1,2);
    for regionIndex = 1:2
        nexttile;
        hold on;
        for methodIndex = 1:3
            rows = summary.region == regions(regionIndex) & ...
                summary.methodName == methods(methodIndex);
            plot(summary.snrDb(rows),summary.(metrics{metricIndex})(rows), ...
                '-o','DisplayName',methods(methodIndex));
        end
        grid on;
        xlabel('SNR (dB)'); ylabel(yLabels{metricIndex});
        title(regions(regionIndex));
        legend('Location','best','Interpreter','none');
    end
    exportgraphics(figureHandle,fullfile(output,fileNames{metricIndex}),'Resolution',160);
    close(figureHandle);
end
end

function localWriteMarkdown(path,report,config)
file = fopen(path,'w');
if file < 0, error('V3:ReportWrite','Cannot write final report.'); end
cleanup = onCleanup(@()fclose(file));
fprintf(file,'# SF12 V3 正式报告\n\n');
fprintf(file,'算法签名：`%s`。\n\n',report.algorithmSignature);
fprintf(file,['本报告使用 -30:-21 dB、每点 5 个完整过境的 Formal V2。' ...
    '三方法同帧配对；置信区间以完整过境为重采样单位。\n\n']);
fprintf(file,'Paper 分支固定标记为 `%s`，不是论文 Figure 10/11 原条件复现。\n\n', ...
    report.paperIdentity);
fprintf(file,'## 产物\n\n');
fprintf(file,'- `v3_formal_summary.csv`：SER、硬 BER、ML 软 BER、PER、CFO、goodput 和运行时间。\n');
fprintf(file,'- `v3_symbol_cfo_rmse.csv`：112 个载荷位置的逐符号 CFO RMSE。\n');
fprintf(file,'- `v3_paired_complete_pass_ci.csv`：完整过境配对 bootstrap 95%% 区间。\n');
fprintf(file,'- `ser_snr.png`、`soft_ber_snr.png`、`per_snr.png`、`cfo_rmse_snr.png`、`goodput_snr.png`。\n\n');
fprintf(file,'## Paper Midamble 开销\n\n');
fprintf(file,['38 个 Midamble 相对 120 符号无 Midamble 帧增加 %.2f%% airtime；' ...
    '占 158 符号共同时间轴 %.2f%%。\n\n'], ...
    100*report.paperOverhead.extraAirtimeFraction, ...
    100*report.paperOverhead.timelineFraction);
fprintf(file,'## 固定边界\n\n');
fprintf(file,['物理 SF=%d，有效数据 SF=%d，spacing=%d，CR3，112 载荷符号，640 信息位；' ...
    '接收机 `usesOrbitPrior=false`。SF11 与 V3 的全部固定差异见项目根目录 ' ...
    '`V3_SF11_DIFFERENCES.md`，不得从最终报告删除。\n\n'], ...
    config.physicalSf,config.effectiveDataSf,config.dataBinSpacing);
fprintf(file,['性能排序是冻结参数后的盲测观察，不是单元测试或调参目标。' ...
    '所有未满足预期的点应原样保留。\n']);
clear cleanup
end
