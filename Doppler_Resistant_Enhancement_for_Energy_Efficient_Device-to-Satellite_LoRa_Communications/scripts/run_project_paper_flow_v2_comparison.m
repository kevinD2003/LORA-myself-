function result = run_project_paper_flow_v2_comparison()
%RUN_PROJECT_PAPER_FLOW_V2_COMPARISON Known-symbol paper flow on frozen V23 IQ.
%   The original five-method result supplies paired reference errors and a
%   fingerprint for every frame. Two new receivers process every physical
%   symbol, including the 37 already-known V4 midambles.

root = dreSetupPaths(true);
v4Root = fullfile(fileparts(root),'Lora(eg)','comparison_experiments', ...
    'stage55_sf12_sf11_flow_v4_noldro');
basePath = fullfile(root,'results','project_formal_v23_verified', ...
    'project_formal_v23.mat');
loaded = load(basePath,'result');
base = loaded.result;
if ~strcmp(base.status,'COMPLETE') || ~base.pairedFrames || ...
        numel(base.cells)~=20 || base.config.packetCountPerCell~=1000
    error('DRE:V23BaseInvalid','Verified 1000-packet V23 result is required.');
end
for k=1:size(base.sourceHashes,1)
    if ~strcmp(base.sourceHashes(k,2),localSha256( ...
            char(base.sourceHashes(k,1))))
        error('DRE:V23SourceChanged','V4 source/config changed after V23 run.');
    end
end
config = base.config;
config.identity = 'dietl-paper-full-symbol-v2-on-v23-1000-paired';
config.algorithmVersion = 'eq18-to-22-known-midamble-v2';
config.methodIds = [config.methodIds, ...
    {'dietl-fixed-lr-full-symbol-v2','dietl-adaptive-lr-full-symbol-v2'}];
config.methodLabels = [config.methodLabels, ...
    {'Dietl Fixed + known midambles','Dietl Adaptive + known midambles'}];
ownFiles = { ...
    fullfile(root,'scripts','run_project_paper_flow_v2_comparison.m'); ...
    fullfile(root,'src','dreDecodePaperFlowOnLayout.m'); ...
    fullfile(root,'src','dreProjectPaperFlowDecode.m'); ...
    fullfile(root,'src','dreEstimateCentroids.m'); ...
    fullfile(root,'src','dreDecodeProjectHardBits.m')};
sourceHashes = strings(numel(ownFiles),2);
for k=1:numel(ownFiles)
    sourceHashes(k,:) = [string(ownFiles{k}),string(localSha256(ownFiles{k}))];
end
identity = struct('config',config,'baseSignature',base.signature, ...
    'sourceHashes',sourceHashes);
signature = dreConfigurationSignature(identity);
output = fullfile(root,'results','project_paper_flow_v2');
if ~isfolder(output), mkdir(output); end
matPath = fullfile(output,'project_paper_flow_v2.mat');
if isfile(matPath)
    cached = load(matPath,'result');
    if ~strcmp(cached.result.signature,signature)
        error('DRE:PaperFlowSignatureMismatch','Existing result has another identity.');
    end
    result = cached.result;
    localWriteSidecars(result.table,result.config,output);
    fprintf('Reusing complete known-midamble paper-flow comparison.\n');
    return
end

cells = cell(numel(base.cells),1);
for cellIndex=1:numel(base.cells)
    cells{cellIndex} = localRunCell(base.cells(cellIndex),output,config, ...
        signature,v4Root);
end
cells = vertcat(cells{:});
summary = localBuildTable(cells,config);
result = struct('status','COMPLETE','signature',signature, ...
    'baseSignature',base.signature,'config',config, ...
    'sourceHashes',sourceHashes,'cells',cells,'table',summary, ...
    'pairedFrames',true,'knownMidamblesUsed',config.v4.paperMidambleCount, ...
    'note','Known V4 midambles are pre-existing shared-frame overhead.');
save(matPath,'result','-v7.3');
localWriteSidecars(summary,config,output);
end

function cellResult = localRunCell(baseCell,output,config,signature,v4Root)
caseIndex = baseCell.caseIndex;
snrDb = baseCell.snrDb;
folder = fullfile(output,'cells',sprintf('case%d',caseIndex), ...
    sprintf('snr_%+03d',snrDb));
if ~isfolder(folder), mkdir(folder); end
cellPath = fullfile(folder,'cell.mat');
checkpointPath = fullfile(folder,'checkpoint.mat');
cellSignature = dreConfigurationSignature(struct('parent',signature, ...
    'baseCellSignature',baseCell.signature,'caseIndex',caseIndex,'snrDb',snrDb));
if isfile(cellPath)
    cached = load(cellPath,'cellResult');
    if ~strcmp(cached.cellResult.signature,cellSignature)
        error('DRE:PaperFlowCellIdentity','Existing cell signature differs.');
    end
    cellResult = cached.cellResult;
    fprintf('Reusing paper-flow case %d SNR %+g.\n',caseIndex,snrDb);
    return
end
n = config.packetCountPerCell;
if isfile(checkpointPath)
    saved = load(checkpointPath,'state','savedSignature');
    if ~strcmp(saved.savedSignature,cellSignature)
        error('DRE:PaperFlowCheckpointIdentity','Checkpoint identity changed.');
    end
    state = saved.state;
else
    state = struct('completed',0,'errors',zeros(n,7,2,'uint16'), ...
        'fingerprintVerified',false(n,1));
    state.errors(:,1:5,:) = baseCell.errors;
end
centroidConfig = struct('samplesPerSymbol',config.v4.samplesPerSymbol, ...
    'zeroPaddingFactor',config.zeroPaddingFactor, ...
    'centroidSampleCount',config.centroidSampleCount);
snrIndex = find(config.snrDb==snrDb,1);
for packetIndex=state.completed+1:n
    key = struct('planVersion','unified-v16-test','phase','paired-grid', ...
        'track','B-method-aligned','channel','AWGN', ...
        'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
        'replicateId',packetIndex,'packetId',packetIndex, ...
        'eventType','paired-frame','eventIndex',caseIndex*100+snrIndex, ...
        'sampleIndex',0);
    ledger = v4EventRandomLedger(config.randomSeedRoot,key);
    frame = v4GenerateBCaseAnchorFrame(config.v4, ...
        config.caseStartTimeSec(caseIndex),snrDb,ledger);
    if ~isequal(frame.observation.sampleFingerprint, ...
            baseCell.fingerprints(packetIndex,:))
        error('DRE:FrameMismatch','Current IQ differs from frozen V23 frame.');
    end
    state.fingerprintVerified(packetIndex) = true;
    centroid = dreEstimateCentroids( ...
        frame.observation.rxPhysical,centroidConfig);
    for method=6:7
        mode='fixed';
        if method==7, mode='adaptive'; end
        receiver = dreProjectPaperFlowDecode( ...
            frame.observation,config,mode,centroid.rawBins);
        if receiver.usesPayloadTruth || receiver.usesOrbitTruth || ...
                receiver.knownMidambleCount~=config.v4.paperMidambleCount
            error('DRE:PaperFlowContract','Receiver violated known-symbol contract.');
        end
        state.errors(packetIndex,method,1) = uint16(sum( ...
            receiver.detectedPhysicalBins~=frame.truth.payloadPhysicalBins));
        state.errors(packetIndex,method,2) = uint16(sum( ...
            receiver.hardDecodedDataBits(:)~=frame.truth.dataBits(:)));
    end
    state.completed = packetIndex;
    if mod(packetIndex,25)==0 || packetIndex==n
        savedSignature = cellSignature; %#ok<NASGU>
        tempPath = [checkpointPath '.tmp'];
        save(tempPath,'state','savedSignature','-v7.3');
        movefile(tempPath,checkpointPath,'f');
        fprintf('Known-midamble paper flow case %d SNR %+g: %d/%d\n', ...
            caseIndex,snrDb,packetIndex,n);
    end
end
if ~all(state.fingerprintVerified)
    error('DRE:FrameVerificationIncomplete','Not all IQ fingerprints matched.');
end
cellResult = struct('status','COMPLETE','signature',cellSignature, ...
    'baseCellSignature',baseCell.signature,'caseIndex',caseIndex, ...
    'snrDb',snrDb,'packetCount',n,'errors',state.errors, ...
    'fingerprintVerified',state.fingerprintVerified);
save(cellPath,'cellResult','-v7.3');
end

function summary = localBuildTable(cells,config)
nRows = numel(cells)*numel(config.methodIds);
caseIndex = zeros(nRows,1); snrDb = zeros(nRows,1);
methodId = strings(nRows,1); methodLabel = strings(nRows,1);
packetCount = zeros(nRows,1); symbolErrors = zeros(nRows,1);
symbolCount = zeros(nRows,1); bitErrors = zeros(nRows,1);
bitCount = zeros(nRows,1); ser = zeros(nRows,1); ber = zeros(nRows,1);
serLow95 = zeros(nRows,1); serHigh95 = zeros(nRows,1);
berLow95 = zeros(nRows,1); berHigh95 = zeros(nRows,1);
adaptiveSerReduction = zeros(nRows,1);
adaptiveSerReductionLow95 = zeros(nRows,1);
adaptiveSerReductionHigh95 = zeros(nRows,1);
adaptiveBerReduction = zeros(nRows,1);
adaptiveBerReductionLow95 = zeros(nRows,1);
adaptiveBerReductionHigh95 = zeros(nRows,1);
row=0;
for cellIndex=1:numel(cells)
    e = double(cells(cellIndex).errors);
    n = cells(cellIndex).packetCount;
    stream = RandStream('mt19937ar','Seed', ...
        946200000+cells(cellIndex).caseIndex*100+round(cells(cellIndex).snrDb+100));
    bootstrapSer = zeros(2000,7); bootstrapBer = zeros(2000,7);
    for draw=1:2000
        sample = randi(stream,n,n,1);
        bootstrapSer(draw,:) = sum(e(sample,:,1),1)/ ...
            (n*config.v4.payloadSymbolCount);
        bootstrapBer(draw,:) = sum(e(sample,:,2),1)/ ...
            (n*config.v4.informationBitCount);
    end
    serBounds = prctile(bootstrapSer,[2.5 97.5],1);
    berBounds = prctile(bootstrapBer,[2.5 97.5],1);
    reductionSerBounds = prctile(bootstrapSer(:,5)-bootstrapSer(:,7), ...
        [2.5 97.5]);
    reductionBerBounds = prctile(bootstrapBer(:,5)-bootstrapBer(:,7), ...
        [2.5 97.5]);
    for method=1:7
        row=row+1;
        caseIndex(row)=cells(cellIndex).caseIndex;
        snrDb(row)=cells(cellIndex).snrDb;
        methodId(row)=string(config.methodIds{method});
        methodLabel(row)=string(config.methodLabels{method});
        packetCount(row)=n;
        symbolErrors(row)=sum(e(:,method,1));
        symbolCount(row)=n*config.v4.payloadSymbolCount;
        bitErrors(row)=sum(e(:,method,2));
        bitCount(row)=n*config.v4.informationBitCount;
        ser(row)=symbolErrors(row)/symbolCount(row);
        ber(row)=bitErrors(row)/bitCount(row);
        serLow95(row)=serBounds(1,method);
        serHigh95(row)=serBounds(2,method);
        berLow95(row)=berBounds(1,method);
        berHigh95(row)=berBounds(2,method);
        adaptiveSerReduction(row)= ...
            (sum(e(:,5,1))-sum(e(:,7,1)))/symbolCount(row);
        adaptiveSerReductionLow95(row)=reductionSerBounds(1);
        adaptiveSerReductionHigh95(row)=reductionSerBounds(2);
        adaptiveBerReduction(row)= ...
            (sum(e(:,5,2))-sum(e(:,7,2)))/bitCount(row);
        adaptiveBerReductionLow95(row)=reductionBerBounds(1);
        adaptiveBerReductionHigh95(row)=reductionBerBounds(2);
    end
end
summary = table(caseIndex,snrDb,methodId,methodLabel,packetCount, ...
    symbolErrors,symbolCount,bitErrors,bitCount,ser,serLow95,serHigh95, ...
    ber,berLow95,berHigh95,adaptiveSerReduction, ...
    adaptiveSerReductionLow95,adaptiveSerReductionHigh95, ...
    adaptiveBerReduction,adaptiveBerReductionLow95, ...
    adaptiveBerReductionHigh95);
end

function localWriteSidecars(summary,config,output)
writetable(summary,fullfile(output,'project_paper_flow_v2_summary.csv'));
figure('Visible','off','Color','w','Position',[100 100 1200 700]);
tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
for metricIndex=1:2
    metric={'ser','ber'};
    denominator={'symbolCount','bitCount'};
    for caseIndex=1:2
        nexttile;
        for method=1:numel(config.methodIds)
            rows=summary.caseIndex==caseIndex & ...
                summary.methodId==string(config.methodIds{method});
            values=max(summary.(metric{metricIndex})(rows), ...
                0.5./summary.(denominator{metricIndex})(rows));
            semilogy(summary.snrDb(rows),values,'o-','LineWidth',1.2);hold on;
        end
        grid on;xlabel('SNR (dB)');ylabel(upper(metric{metricIndex}));
        title(sprintf('%s, 1000 paired packets/SNR', ...
            config.caseNames{caseIndex}));
        if metricIndex==1 && caseIndex==1
            legend(config.methodLabels,'Location','southwest');
        end
    end
end
exportgraphics(gcf,fullfile(output,'project_paper_flow_v2_ser_ber.png'), ...
    'Resolution',180);
close(gcf);
end

function value=localSha256(path)
file=fopen(path,'rb');
if file<0,error('DRE:SourceMissing','Source file not found: %s',path);end
closer=onCleanup(@()fclose(file));
bytes=fread(file,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
raw=typecast(digest.digest(),'uint8');
value=lower(reshape(dec2hex(raw,2).',1,[]));
end
