function result = run_project_comparison(options)
%RUN_PROJECT_COMPARISON Five receivers on paired current-project V4 frames.

arguments
    options.PacketCountPerCell (1,1) double {mustBeInteger,mustBePositive} = 100
    options.SnrDb (:,1) double = [-27;-24;-21]
    options.CaseStartTimeSec (:,1) double = [-366;0]
end
root = dreSetupPaths(true);
paperPath = fullfile(root,'results','paper_reproduction','table_iv_run.mat');
if ~isfile(paperPath)
    error('DRE:PaperAnchorRequired', ...
        'Run run_paper_table_iv successfully before project comparison.');
end
fullPhyPath = fullfile(root,'results','paper_full_phy','full_phy_run.mat');
if ~isfile(fullPhyPath)
    error('DRE:FullPhyRequired', ...
        'Run the formal run_paper_full_phy before project comparison.');
end
fullPhy = load(fullPhyPath,'result');
if ~isfield(fullPhy,'result') || ~strcmp(fullPhy.result.status,'COMPLETE')
    error('DRE:FullPhyIncomplete', ...
        'Project comparison requires the complete 3000-overpass full-PHY run.');
end
paper = load(paperPath,'result');
if ~isfield(paper,'result') || ~strcmp(paper.result.status,'COMPLETE')
    error('DRE:PaperAnchorIncomplete','Paper-anchor result is not complete.');
end
requiredSnr = [0;-5;-10;-15;-20];
if ~isinf(paper.result.config.maximumPackets) || ...
        ~isequal(paper.result.config.snrDb(:),requiredSnr)
    error('DRE:PaperAnchorNotFormal', ...
        'Project comparison requires the complete five-SNR paper overpass.');
end
config = dreProjectConfig();
config.packetCountPerCell = options.PacketCountPerCell;
config.snrDb = options.SnrDb;
config.caseStartTimeSec = options.CaseStartTimeSec;
config.v4 = sf12NoLdroSf11FlowConfig();
signatureConfig = config;
signatureConfig.paperAnchorSignature = paper.result.signature;
signatureConfig.fullPhySignature = fullPhy.result.signature;
signature = dreConfigurationSignature(signatureConfig);
output = fullfile(root,'results','project_comparison');
if ~isfolder(output), mkdir(output); end
matPath = fullfile(output,'project_comparison.mat');
if isfile(matPath)
    existing = load(matPath,'result');
    if isfield(existing,'result') && strcmp(existing.result.signature,signature)
        result = existing.result;
        result.paperAnchorSignature = paper.result.signature;
        result.fullPhySignature = fullPhy.result.signature;
        save(matPath,'result','-v7.3');
        localWriteSidecars(result.table,result.config,output);
        fprintf('Reusing project-comparison result with matching signature.\n');
        return
    end
end
methodCount = numel(config.methodIds);
recordCount = numel(config.caseStartTimeSec)*numel(config.snrDb)*methodCount;
caseIndexOut = zeros(recordCount,1);
caseNameOut = strings(recordCount,1);
startOut = zeros(recordCount,1);
snrOut = zeros(recordCount,1);
methodIdOut = strings(recordCount,1);
methodLabelOut = strings(recordCount,1);
symbolErrorsOut = zeros(recordCount,1);
bitErrorsOut = zeros(recordCount,1);
symbolCountOut = zeros(recordCount,1);
bitCountOut = zeros(recordCount,1);
record = 0;
for caseIndex = 1:numel(config.caseStartTimeSec)
    for snrIndex = 1:numel(config.snrDb)
        symbolErrors = zeros(methodCount,1);
        bitErrors = zeros(methodCount,1);
        for packetIndex = 1:config.packetCountPerCell
            key = struct('planVersion',config.identity,'phase','project-comparison', ...
                'track','B-method-aligned','channel','AWGN', ...
                'comparisonMode','case-anchor-controlled', ...
                'snrDb',config.snrDb(snrIndex),'replicateId',packetIndex, ...
                'packetId',packetIndex,'eventType','paired-frame', ...
                'eventIndex',caseIndex*100+snrIndex,'sampleIndex',0);
            ledger = v4EventRandomLedger(config.randomSeedRoot,key);
            frame = v4GenerateBCaseAnchorFrame(config.v4, ...
                config.caseStartTimeSec(caseIndex),config.snrDb(snrIndex),ledger);
            common = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:), ...
                config.v4,SearchStepBins=config.commonBootstrapSearchStepBins);
            receivers = {v4HuangUnifiedDecodeV2(frame.observation,common,config.v4), ...
                v4Stage55UnifiedDecodeV16(frame.observation,common,config.v4), ...
                v4PaperMidamblePointUnifiedV6(frame.observation,common,config.v4), ...
                dreProjectLinearRegressionDecode(frame.observation,config,'fixed'), ...
                dreProjectLinearRegressionDecode(frame.observation,config,'adaptive')};
            for method = 1:methodCount
                if receivers{method}.usesPayloadTruth || receivers{method}.usesOrbitTruth
                    error('DRE:TruthLeakage','Receiver %s uses simulation truth.', ...
                        config.methodIds{method});
                end
                symbolErrors(method) = symbolErrors(method)+sum( ...
                    receivers{method}.detectedPhysicalBins ~= ...
                    frame.truth.payloadPhysicalBins);
                bitErrors(method) = bitErrors(method)+sum( ...
                    receivers{method}.hardDecodedDataBits(:) ~= ...
                    frame.truth.dataBits(:));
            end
            if mod(packetIndex,10)==0 || packetIndex==config.packetCountPerCell
                fprintf('Project case %d SNR %+g dB: %d/%d packets\n', ...
                    caseIndex,config.snrDb(snrIndex),packetIndex, ...
                    config.packetCountPerCell);
            end
        end
        for method = 1:methodCount
            record = record+1;
            caseIndexOut(record) = caseIndex;
            if caseIndex <= numel(config.caseNames)
                caseNameOut(record) = string(config.caseNames{caseIndex});
            else
                caseNameOut(record) = "case-"+caseIndex;
            end
            startOut(record) = config.caseStartTimeSec(caseIndex);
            snrOut(record) = config.snrDb(snrIndex);
            methodIdOut(record) = string(config.methodIds{method});
            methodLabelOut(record) = string(config.methodLabels{method});
            symbolErrorsOut(record) = symbolErrors(method);
            bitErrorsOut(record) = bitErrors(method);
            symbolCountOut(record) = config.packetCountPerCell*config.v4.payloadSymbolCount;
            bitCountOut(record) = config.packetCountPerCell*config.v4.informationBitCount;
        end
    end
end
tableOut = table(caseIndexOut,caseNameOut,startOut,snrOut,methodIdOut, ...
    methodLabelOut,symbolErrorsOut,symbolCountOut,bitErrorsOut,bitCountOut, ...
    symbolErrorsOut./symbolCountOut,bitErrorsOut./bitCountOut, ...
    'VariableNames',{'caseIndex','caseName','startTimeSec','snrDb','methodId', ...
    'methodLabel','symbolErrors','symbolCount','bitErrors','bitCount','ser','ber'});
localWriteSidecars(tableOut,config,output);
result = struct('status','COMPLETE','signature',signature,'config',config, ...
    'table',tableOut,'paperAnchorSignature',paper.result.signature, ...
    'fullPhySignature',fullPhy.result.signature, ...
    'pairedFrames',true,'receiverTruthLeakageChecked',true);
save(matPath,'result','-v7.3');
end

function localWriteSidecars(tableOut,config,output)
writetable(tableOut,fullfile(output,'project_comparison.csv'));
methodCount = numel(config.methodIds);
figure('Visible','off','Color','w','Position',[100 100 1100 650]);
tiledlayout(2,numel(config.caseStartTimeSec),'Padding','compact','TileSpacing','compact');
for metricIndex = 1:2
    metric = {'ser','ber'};
    denominator = {'symbolCount','bitCount'};
    for caseIndex = 1:numel(config.caseStartTimeSec)
        nexttile;
        for method = 1:methodCount
            mask = tableOut.caseIndex==caseIndex & ...
                tableOut.methodId==string(config.methodIds{method});
            semilogy(tableOut.snrDb(mask),max(tableOut.(metric{metricIndex})(mask), ...
                0.5./tableOut.(denominator{metricIndex})(mask)), ...
                'o-','LineWidth',1.3); hold on;
        end
        grid on; xlabel('SNR (dB)'); ylabel(upper(metric{metricIndex}));
        title(sprintf('%s, t_0=%g s',char(config.caseNames{caseIndex}), ...
            config.caseStartTimeSec(caseIndex)));
        if metricIndex==1 && caseIndex==1
            legend(config.methodLabels,'Location','southwest');
        end
    end
end
exportgraphics(gcf,fullfile(output,'project_comparison.png'),'Resolution',180);
close(gcf);
end
