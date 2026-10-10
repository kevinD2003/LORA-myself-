function result = run_project_formal_v23_comparison()
%RUN_PROJECT_FORMAL_V23_COMPARISON Five methods on the V4 V23 frozen 1000 frames.
%   Reuses the verified per-packet V23 reference results and evaluates both
%   Dietl receivers on exactly the same regenerated IQ frames and seeds.

root = dreSetupPaths(true);
v4Root = fullfile(fileparts(root),'Lora(eg)','comparison_experiments', ...
    'stage55_sf12_sf11_flow_v4_noldro');
addpath(fullfile(v4Root,'scripts'));
paper = load(fullfile(root,'results','paper_reproduction','table_iv_run.mat'),'result');
fullPhy = load(fullfile(root,'results','paper_full_phy','full_phy_run.mat'),'result');
if ~strcmp(paper.result.status,'COMPLETE') || ...
        ~strcmp(fullPhy.result.status,'COMPLETE') || ...
        fullPhy.result.config.fullPhyOverpasses~=3000
    error('DRE:PaperAnchorsIncomplete','Formal paper anchors are required.');
end
config = dreProjectConfig();
config.identity = 'dietl-on-v4-unified-v23-1000-paired-v1';
config.algorithmVersion = 'five-method-v23-frozen-paired-v1';
config.snrDb = (-30:-21).';
config.packetCountPerCell = 1000;
config.randomSeedRoot = 884000000;
config.methodIds{1} = 'huang-prec-unified-v9';
config.methodLabels{1} = 'Huang-PREC V9';
config.v4 = sf12NoLdroSf11FlowConfig();
sourceHashes = localSourceHashes(root,v4Root);
sourceSignatures = strings(numel(config.caseStartTimeSec),numel(config.snrDb),2);
sourceRecordHashes = strings(numel(config.caseStartTimeSec),numel(config.snrDb),2);
for caseIndex = 1:numel(config.caseStartTimeSec)
    for snrIndex = 1:numel(config.snrDb)
        [huang,unified] = localLoadV23(v4Root,caseIndex,config.snrDb(snrIndex));
        sourceSignatures(caseIndex,snrIndex,1) = string(huang.signature);
        sourceSignatures(caseIndex,snrIndex,2) = string(unified.signature);
        sourceRecordHashes(caseIndex,snrIndex,1) = ...
            string(localArraySha256(huang.packetErrors));
        sourceRecordHashes(caseIndex,snrIndex,2) = ...
            string(localArraySha256(unified.packetErrors));
    end
end
identity = struct('config',config,'sourceHashes',sourceHashes, ...
    'sourceSignatures',sourceSignatures, ...
    'sourceRecordHashes',sourceRecordHashes, ...
    'paperSignature',paper.result.signature, ...
    'fullPhySignature',fullPhy.result.signature);
signature = dreConfigurationSignature(identity);
output = fullfile(root,'results','project_formal_v23_verified');
if ~isfolder(output), mkdir(output); end
matPath = fullfile(output,'project_formal_v23.mat');
if isfile(matPath)
    loaded = load(matPath,'result');
    if strcmp(loaded.result.signature,signature)
        result = loaded.result;
        localWriteSidecars(result.table,result.config,output);
        fprintf('Reusing formal V23 five-method comparison.\n');
        return
    end
    error('DRE:FormalSignatureMismatch', ...
        'Existing formal result has a different source/configuration signature.');
end
cellCount = numel(config.caseStartTimeSec)*numel(config.snrDb);
cells = cell(cellCount,1);
cellNumber = 0;
for caseIndex = 1:numel(config.caseStartTimeSec)
    for snrIndex = 1:numel(config.snrDb)
        cellNumber = cellNumber+1;
        cells{cellNumber} = localRunCell(root,v4Root,output,config, ...
            caseIndex,snrIndex,signature);
    end
end
cells = vertcat(cells{:});
tableOut = localBuildTable(cells,config);
result = struct('status','COMPLETE','signature',signature,'config',config, ...
    'sourceHashes',sourceHashes,'sourceSignatures',sourceSignatures, ...
    'sourceRecordHashes',sourceRecordHashes, ...
    'paperSignature',paper.result.signature, ...
    'fullPhySignature',fullPhy.result.signature, ...
    'cells',cells,'table',tableOut,'pairedFrames',true, ...
    'referenceIdentity','V4 Unified V23 / 1000-packet cells');
save(matPath,'result','-v7.3');
localWriteSidecars(tableOut,config,output);
end

function cellResult = localRunCell(root,v4Root,output,config,caseIndex,snrIndex,signature)
snrDb = config.snrDb(snrIndex);
[huang,unified] = localLoadV23(v4Root,caseIndex,snrDb);
folder = fullfile(output,'cells',sprintf('case%d',caseIndex), ...
    sprintf('snr_%+03d',snrDb));
if ~isfolder(folder), mkdir(folder); end
cellPath = fullfile(folder,'cell.mat');
checkpointPath = fullfile(folder,'checkpoint.mat');
cellSignature = dreConfigurationSignature(struct('parent',signature, ...
    'caseIndex',caseIndex,'snrDb',snrDb, ...
    'huangSignature',huang.signature,'unifiedSignature',unified.signature));
if isfile(cellPath)
    loaded = load(cellPath,'cellResult');
    if strcmp(loaded.cellResult.signature,cellSignature)
        cellResult = loaded.cellResult;
        fprintf('Reusing V23 case %d SNR %+g cell.\n',caseIndex,snrDb);
        return
    end
    error('DRE:CellSignatureMismatch','Existing cell has another signature.');
end
n = config.packetCountPerCell;
if isfile(checkpointPath)
    loaded = load(checkpointPath,'state','cellSignatureSaved');
    if ~strcmp(loaded.cellSignatureSaved,cellSignature)
        error('DRE:CheckpointSignatureMismatch','Checkpoint identity changed.');
    end
    state = loaded.state;
else
    state = struct('completed',0,'errors',zeros(n,5,2,'uint16'), ...
        'fingerprints',zeros(n,3),'referenceSpotCheckPassed',false);
    state.errors(:,1,1) = huang.packetErrors(:,1);
    state.errors(:,1,2) = huang.packetErrors(:,2);
    state.errors(:,2,:) = unified.packetErrors(:,2,:);
    state.errors(:,3,:) = unified.packetErrors(:,3,:);
end
centroidConfig = struct('samplesPerSymbol',config.v4.samplesPerSymbol, ...
    'zeroPaddingFactor',config.zeroPaddingFactor, ...
    'centroidSampleCount',config.centroidSampleCount);
selected = [];
for packetIndex = state.completed+1:n
    key = struct('planVersion','unified-v16-test','phase','paired-grid', ...
        'track','B-method-aligned','channel','AWGN', ...
        'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
        'replicateId',packetIndex,'packetId',packetIndex, ...
        'eventType','paired-frame','eventIndex',caseIndex*100+snrIndex, ...
        'sampleIndex',0);
    ledger = v4EventRandomLedger(config.randomSeedRoot,key);
    frame = v4GenerateBCaseAnchorFrame(config.v4, ...
        config.caseStartTimeSec(caseIndex),snrDb,ledger);
    state.fingerprints(packetIndex,:) = frame.observation.sampleFingerprint;
    if packetIndex==1 && ~state.referenceSpotCheckPassed
        localSpotCheck(frame,config,huang,unified);
        state.referenceSpotCheckPassed = true;
    end
    if isempty(selected)
        selected = [frame.observation.layout.bootstrapRows; ...
            frame.observation.layout.dataRows];
    end
    centroid = dreEstimateCentroids( ...
        frame.observation.rxPhysical(selected,:),centroidConfig);
    for method=4:5
        mode = 'fixed';
        if method==5, mode='adaptive'; end
        decoded = dreProjectLinearRegressionDecode( ...
            frame.observation,config,mode,centroid.rawBins);
        if decoded.usesPayloadTruth || decoded.usesOrbitTruth
            error('DRE:TruthLeakage','Dietl receiver accessed simulation truth.');
        end
        state.errors(packetIndex,method,1) = uint16(sum( ...
            decoded.detectedPhysicalBins~=frame.truth.payloadPhysicalBins));
        state.errors(packetIndex,method,2) = uint16(sum( ...
            decoded.hardDecodedDataBits(:)~=frame.truth.dataBits(:)));
    end
    state.completed = packetIndex;
    if mod(packetIndex,25)==0 || packetIndex==n
        cellSignatureSaved = cellSignature; %#ok<NASGU>
        tempPath = [checkpointPath '.tmp'];
        save(tempPath,'state','cellSignatureSaved','-v7.3');
        movefile(tempPath,checkpointPath,'f');
        fprintf('Formal V23 case %d SNR %+g: %d/%d frames\n', ...
            caseIndex,snrDb,packetIndex,n);
    end
end
if ~state.referenceSpotCheckPassed
    error('DRE:ReferencePairing','V23 reference spot check was not completed.');
end
cellResult = struct('status','COMPLETE','signature',cellSignature, ...
    'caseIndex',caseIndex,'snrDb',snrDb,'packetCount',n, ...
    'errors',state.errors,'fingerprints',state.fingerprints, ...
    'referenceSpotCheckPassed',state.referenceSpotCheckPassed, ...
    'huangSignature',huang.signature,'unifiedSignature',unified.signature);
save(cellPath,'cellResult','-v7.3');
end

function localSpotCheck(frame,config,huang,unified)
v4 = config.v4;
parameters = v4LoadMethodAlignedR3ParametersV1();
common = v4CommonBootstrap(frame.observation.rxPhysical(1:8,:),v4, ...
    SearchStepBins=parameters.searchStepBins);
receivers = {v4HuangPrecUnifiedDecodeV9(frame.observation,v4), ...
    v4Stage55UnifiedDecodeV16(frame.observation,common,v4), ...
    v4PaperMidamblePointUnifiedV6(frame.observation,common,v4)};
expected = [double(huang.packetErrors(1,:)); ...
    squeeze(double(unified.packetErrors(1,2,:))).'; ...
    squeeze(double(unified.packetErrors(1,3,:))).'];
for method=1:3
    observed = [sum(receivers{method}.detectedPhysicalBins~= ...
        frame.truth.payloadPhysicalBins),sum( ...
        receivers{method}.hardDecodedDataBits(:)~=frame.truth.dataBits(:))];
    if ~isequal(double(observed),expected(method,:))
        error('DRE:ReferencePairing', ...
            'Regenerated frame disagrees with the frozen V23 packet record.');
    end
end
end

function [huang,unified] = localLoadV23(v4Root,caseIndex,snrDb)
caseName = sprintf('case%d',caseIndex);
snrName = sprintf('snr_%+03d',snrDb);
huangPath = fullfile(v4Root,'results','method_aligned', ...
    'huang_v9_test',caseName,snrName,'test_cell.mat');
unifiedPath = fullfile(v4Root,'results','method_aligned', ...
    'unified_v16_test',caseName,snrName,'test_cell.mat');
if ~isfile(huangPath) || ~isfile(unifiedPath)
    error('DRE:V23ReferenceMissing','Frozen V23 per-packet results are missing.');
end
h = load(huangPath,'result'); u = load(unifiedPath,'result');
huang = h.result; unified = u.result;
if ~strcmp(huang.status,'COMPLETE') || ~strcmp(unified.status,'COMPLETE') || ...
        huang.fixedPackets~=1000 || unified.fixedPackets~=1000 || ...
        size(huang.packetErrors,1)~=1000 || ...
        ~isequal(size(unified.packetErrors),[1000 3 2]) || ...
        huang.caseIndex~=caseIndex || unified.caseIndex~=caseIndex || ...
        huang.snrDb~=snrDb || unified.snrDb~=snrDb
    error('DRE:V23ReferenceInvalid','Frozen V23 result contract mismatch.');
end
end

function hashes = localSourceHashes(root,v4Root)
ownFiles = { ...
    fullfile(root,'src','dreProjectLinearRegressionDecode.m'); ...
    fullfile(root,'src','dreDecodeLinearRegression.m'); ...
    fullfile(root,'src','dreEstimateCentroids.m'); ...
    fullfile(root,'src','dreDecodeProjectHardBits.m'); ...
    fullfile(root,'scripts','run_project_formal_v23_comparison.m'); ...
    fullfile(v4Root,'src','statistics','v4RunUnifiedV16TestCell.m'); ...
    fullfile(v4Root,'src','statistics','v4RunHuangV9TestCell.m')};
v4Source = dir(fullfile(v4Root,'src','**','*.m'));
v4ConfigM = dir(fullfile(v4Root,'config','*.m'));
v4ConfigJson = dir(fullfile(v4Root,'config','*.json'));
v4Files = [v4Source;v4ConfigM;v4ConfigJson];
files = ownFiles;
for k=1:numel(v4Files)
    files{end+1,1} = fullfile(v4Files(k).folder,v4Files(k).name); %#ok<AGROW>
end
files = unique(files);
hashes = strings(numel(files),2);
for k=1:numel(files)
    hashes(k,1) = string(files{k});
    hashes(k,2) = string(localSha256(files{k}));
end
end

function value = localArraySha256(array)
if ~isa(array,'uint16')
    error('DRE:ReferenceRecordType','V23 packet errors must be uint16.');
end
digest = java.security.MessageDigest.getInstance('SHA-256');
shape = uint64(size(array));
digest.update(typecast(shape(:),'uint8'));
digest.update(typecast(array(:),'uint8'));
raw = typecast(digest.digest(),'uint8');
value = lower(reshape(dec2hex(raw,2).',1,[]));
end

function value = localSha256(path)
file = fopen(path,'rb');
if file<0, error('DRE:SourceMissing','Source file not found: %s',path); end
closer = onCleanup(@()fclose(file));
bytes = fread(file,Inf,'*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
raw = typecast(digest.digest(),'uint8');
value = lower(reshape(dec2hex(raw,2).',1,[]));
end

function summary = localBuildTable(cells,config)
rows = numel(cells)*numel(config.methodIds);
caseIndex = zeros(rows,1); snrDb = zeros(rows,1);
methodId = strings(rows,1); methodLabel = strings(rows,1);
packetCount = zeros(rows,1); symbolErrors = zeros(rows,1);
bitErrors = zeros(rows,1); symbolCount = zeros(rows,1); bitCount = zeros(rows,1);
ser = zeros(rows,1); ber = zeros(rows,1);
serLow95 = zeros(rows,1); serHigh95 = zeros(rows,1);
berLow95 = zeros(rows,1); berHigh95 = zeros(rows,1);
adaptiveMinusStageSer = zeros(rows,1);
adaptiveMinusStageSerLow95 = zeros(rows,1);
adaptiveMinusStageSerHigh95 = zeros(rows,1);
adaptiveMinusStageBer = zeros(rows,1);
adaptiveMinusStageBerLow95 = zeros(rows,1);
adaptiveMinusStageBerHigh95 = zeros(rows,1);
outputRow = 0;
for c=1:numel(cells)
    errors = double(cells(c).errors);
    n = cells(c).packetCount;
    stream = RandStream('mt19937ar','Seed', ...
        946100000+cells(c).caseIndex*100+round(cells(c).snrDb+100));
    draws = 2000;
    bootSer = zeros(draws,5); bootBer = zeros(draws,5);
    for draw=1:draws
        sample = randi(stream,n,n,1);
        bootSer(draw,:) = sum(errors(sample,:,1),1)/(n*config.v4.payloadSymbolCount);
        bootBer(draw,:) = sum(errors(sample,:,2),1)/(n*config.v4.informationBitCount);
    end
    serBounds = prctile(bootSer,[2.5 97.5],1);
    berBounds = prctile(bootBer,[2.5 97.5],1);
    diffSer = bootSer(:,5)-bootSer(:,2);
    diffBer = bootBer(:,5)-bootBer(:,2);
    diffSerBounds = prctile(diffSer,[2.5 97.5]);
    diffBerBounds = prctile(diffBer,[2.5 97.5]);
    for method=1:numel(config.methodIds)
        outputRow = outputRow+1;
        caseIndex(outputRow)=cells(c).caseIndex;
        snrDb(outputRow)=cells(c).snrDb;
        methodId(outputRow)=string(config.methodIds{method});
        methodLabel(outputRow)=string(config.methodLabels{method});
        packetCount(outputRow)=n;
        symbolErrors(outputRow)=sum(errors(:,method,1));
        bitErrors(outputRow)=sum(errors(:,method,2));
        symbolCount(outputRow)=n*config.v4.payloadSymbolCount;
        bitCount(outputRow)=n*config.v4.informationBitCount;
        ser(outputRow)=symbolErrors(outputRow)/symbolCount(outputRow);
        ber(outputRow)=bitErrors(outputRow)/bitCount(outputRow);
        serLow95(outputRow)=serBounds(1,method);
        serHigh95(outputRow)=serBounds(2,method);
        berLow95(outputRow)=berBounds(1,method);
        berHigh95(outputRow)=berBounds(2,method);
        adaptiveMinusStageSer(outputRow)= ...
            (sum(errors(:,5,1))-sum(errors(:,2,1)))/symbolCount(outputRow);
        adaptiveMinusStageSerLow95(outputRow)=diffSerBounds(1);
        adaptiveMinusStageSerHigh95(outputRow)=diffSerBounds(2);
        adaptiveMinusStageBer(outputRow)= ...
            (sum(errors(:,5,2))-sum(errors(:,2,2)))/bitCount(outputRow);
        adaptiveMinusStageBerLow95(outputRow)=diffBerBounds(1);
        adaptiveMinusStageBerHigh95(outputRow)=diffBerBounds(2);
    end
end
summary = table(caseIndex,snrDb,methodId,methodLabel,packetCount, ...
    symbolErrors,symbolCount,bitErrors,bitCount,ser,serLow95,serHigh95, ...
    ber,berLow95,berHigh95,adaptiveMinusStageSer, ...
    adaptiveMinusStageSerLow95,adaptiveMinusStageSerHigh95, ...
    adaptiveMinusStageBer,adaptiveMinusStageBerLow95, ...
    adaptiveMinusStageBerHigh95);
end

function localWriteSidecars(summary,config,output)
writetable(summary,fullfile(output,'project_formal_v23_summary.csv'));
figure('Visible','off','Color','w','Position',[100 100 1200 700]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
for metricIndex=1:2
    metric = {'ser','ber'};
    denominator = {'symbolCount','bitCount'};
    for caseIndex=1:2
        nexttile;
        for method=1:numel(config.methodIds)
            rows = summary.caseIndex==caseIndex & ...
                summary.methodId==string(config.methodIds{method});
            values = max(summary.(metric{metricIndex})(rows), ...
                0.5./summary.(denominator{metricIndex})(rows));
            semilogy(summary.snrDb(rows),values,'o-','LineWidth',1.3); hold on;
        end
        grid on;
        xlabel('SNR (dB)'); ylabel(upper(metric{metricIndex}));
        title(sprintf('%s, %d paired packets/SNR', ...
            config.caseNames{caseIndex},config.packetCountPerCell));
        if metricIndex==1 && caseIndex==1
            legend(config.methodLabels,'Location','southwest');
        end
    end
end
exportgraphics(gcf,fullfile(output,'project_formal_v23_ser_ber.png'), ...
    'Resolution',180);
close(gcf);
end
