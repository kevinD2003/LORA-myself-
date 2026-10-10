function result = run_case1_case2_code_aided_ser()
%RUN_CASE1_CASE2_CODE_AIDED_SER Validate the no-midamble refined receiver.

root = dreSetupPaths(true);
formalPath = fullfile(root,'results','project_formal_v23_verified', ...
    'project_formal_v23.mat');
loaded = load(formalPath,'result');
formal = loaded.result;
if ~strcmp(formal.status,'COMPLETE') || numel(formal.cells)~=20
    error('DRE:CodeAidedSource','Complete formal V23 source is required.');
end
for k=1:size(formal.sourceHashes,1)
    if ~strcmp(formal.sourceHashes(k,2), ...
            localSha256(char(formal.sourceHashes(k,1))))
        error('DRE:CodeAidedV4Changed','A frozen V4 dependency changed.');
    end
end

config = formal.config;
config.identity = 'dietl-code-aided-replay-case1-case2-v3';
config.methodIds = {'dietl-code-aided-replay-v3', ...
    'stage55-unified-v16','paper-midamble-adapted-v6'};
config.methodLabels = {'Dietl robust replay','Stage55 V16','Midamble V6'};
ownFiles = {fullfile(root,'scripts','run_case1_case2_code_aided_ser.m'); ...
    fullfile(root,'src','dreProjectCodeAidedReplayDecode.m'); ...
    fullfile(root,'src','dreProjectRefinedLRDecode.m'); ...
    fullfile(root,'src','dreDecodeRefinedAdaptiveLR.m'); ...
    fullfile(root,'src','dreEstimatePaperCentroids10.m'); ...
    fullfile(root,'src','dreDecodeProjectHardBits.m')};
sourceHashes = strings(numel(ownFiles),2);
for k=1:numel(ownFiles)
    sourceHashes(k,:) = [string(ownFiles{k}),string(localSha256(ownFiles{k}))];
end
signature = dreConfigurationSignature(struct('config',config, ...
    'formalSignature',formal.signature,'sourceHashes',sourceHashes));

output = fullfile(root,'results','case1_case2_code_aided_ser_v3');
if ~isfolder(output),mkdir(output);end
matPath = fullfile(output,'case1_case2_code_aided_ser_v3.mat');
if isfile(matPath)
    cached = load(matPath,'result');
    if ~strcmp(cached.result.signature,signature)
        error('DRE:CodeAidedSignature','Existing result has another signature.');
    end
    result = cached.result;
    localWriteArtifacts(result.table,result.config,output);
    return
end

v4Root = fullfile(fileparts(root),'Lora(eg)','comparison_experiments', ...
    'stage55_sf12_sf11_flow_v4_noldro');
cells = cell(20,1);
for ci=1:2
    for si=1:10
        index=(ci-1)*10+si;
        source=formal.cells(index);
        if ci==1
            cells{index}=localReuseStaticCell(source,config,v4Root,si,signature);
        else
            cells{index}=localRunDynamicCell(source,config,si,signature,output);
        end
    end
end
cells=vertcat(cells{:});
summary=localBuildTable(cells,formal.cells,config);
candidate=summary.methodId=="dietl-code-aided-replay-v3";
midamble=summary.methodId=="paper-midamble-adapted-v6";
candidateRows=summary(candidate,:);midambleRows=summary(midamble,:);
targetPassed=all(candidateRows.symbolErrors<=midambleRows.symbolErrors);
result=struct('status','COMPLETE','signature',signature,'config',config, ...
    'formalSignature',formal.signature,'sourceHashes',sourceHashes, ...
    'cells',cells,'table',summary,'targetPassed',targetPassed, ...
    'criterion','candidate symbol errors <= Midamble V6 in every case/SNR cell');
save(matPath,'result','-v7.3');
localWriteArtifacts(summary,config,output);
if ~targetPassed
    error('DRE:CodeAidedTarget','At least one cell remains worse than Midamble.');
end
end

function cellResult=localReuseStaticCell(source,config,v4Root,si,parentSignature)
snrDb=source.snrDb;
unifiedPath=fullfile(v4Root,'results','method_aligned', ...
    'unified_v16_test','case1',sprintf('snr_%+03d',snrDb),'test_cell.mat');
frozen=load(unifiedPath,'result');frozen=frozen.result;
if ~strcmp(frozen.status,'COMPLETE') || frozen.stageDynamicPackets~=0 || ...
        ~isequal(frozen.packetErrors(:,2,:),source.errors(:,2,:))
    error('DRE:CodeAidedStaticSource','Case1 is not the frozen static branch.');
end
key=localKey(1,si,snrDb,1);
ledger=v4EventRandomLedger(config.randomSeedRoot,key);
frame=v4GenerateBCaseAnchorFrame(config.v4,config.caseStartTimeSec(1), ...
    snrDb,ledger);
if ~isequal(frame.observation.sampleFingerprint,source.fingerprints(1,:))
    error('DRE:CodeAidedStaticPairing','Case1 live frame differs from V23.');
end
receiver=dreProjectCodeAidedReplayDecode(frame.observation,config);
live=uint16([sum(receiver.detectedPhysicalBins~= ...
    frame.truth.payloadPhysicalBins),sum(receiver.hardDecodedDataBits(:)~= ...
    frame.truth.dataBits(:))]);
expected=uint16(squeeze(source.errors(1,2,:))).';
if ~strcmp(receiver.receiverMode,'observable-static') || ~isequal(live,expected)
    error('DRE:CodeAidedStaticMismatch','Static branch differs from Stage55 V16.');
end
cellSignature=dreConfigurationSignature(struct('parent',parentSignature, ...
    'sourceCell',source.signature,'caseIndex',1,'snrDb',snrDb));
cellResult=struct('status','COMPLETE','signature',cellSignature, ...
    'caseIndex',1,'snrDb',snrDb,'packetCount',1000, ...
    'errors',squeeze(source.errors(:,2,:)), ...
    'fingerprintsVerified',true(1000,1),'staticPackets',1000, ...
    'safetyPackets',1000,'replayPackets',0,'dynamicPackets',0, ...
    'reusedFrozenStaticBranch',true);
end

function cellResult=localRunDynamicCell(source,config,si,parentSignature,output)
ci=2;snrDb=source.snrDb;
folder=fullfile(output,'cells','case2',sprintf('snr_%+03d',snrDb));
if ~isfolder(folder),mkdir(folder);end
cellPath=fullfile(folder,'cell.mat');checkpoint=fullfile(folder,'checkpoint.mat');
cellSignature=dreConfigurationSignature(struct('parent',parentSignature, ...
    'sourceCell',source.signature,'caseIndex',ci,'snrDb',snrDb));
if isfile(cellPath)
    cached=load(cellPath,'cellResult');
    if ~strcmp(cached.cellResult.signature,cellSignature)
        error('DRE:CodeAidedCellSignature','Cell identity changed.');
    end
    cellResult=cached.cellResult;return
end
n=1000;
if isfile(checkpoint)
    saved=load(checkpoint,'state','savedSignature');
    if ~strcmp(saved.savedSignature,cellSignature)
        error('DRE:CodeAidedCheckpoint','Checkpoint identity changed.');
    end
    state=saved.state;
else
    state=struct('completed',0,'errors',zeros(n,2,'uint16'), ...
        'fingerprintsVerified',false(n,1),'staticPackets',0, ...
        'safetyPackets',0,'replayPackets',0,'verifiedSafetyLive',false);
end
parameters=v4LoadMethodAlignedR3ParametersV1();
for packetIndex=state.completed+1:n
    key=localKey(ci,si,snrDb,packetIndex);
    ledger=v4EventRandomLedger(config.randomSeedRoot,key);
    frame=v4GenerateBCaseAnchorFrame(config.v4, ...
        config.caseStartTimeSec(ci),snrDb,ledger);
    if ~isequal(frame.observation.sampleFingerprint, ...
            source.fingerprints(packetIndex,:))
        error('DRE:CodeAidedPairing','Regenerated IQ differs from V23.');
    end
    pilots=frame.observation.rxPhysical(1:config.v4.bootstrapPilotCount,:);
    modeParameters=struct('maximumRateBinsPerSec',20, ...
        'modeLargeToCentralRatio',0.75);
    modeEvidence=v4Stage55ObservableModeSelectorV10( ...
        pilots,config.v4,modeParameters);
    common=v4CommonBootstrap(pilots,config.v4, ...
        SearchStepBins=parameters.searchStepBins);
    useFrozenSafety=modeEvidence.staticSelected || median(common.peakRatio)<5.5;
    if useFrozenSafety
        state.errors(packetIndex,:)=uint16(squeeze( ...
            source.errors(packetIndex,2,:))).';
        state.safetyPackets=state.safetyPackets+1;
        state.staticPackets=state.staticPackets+modeEvidence.staticSelected;
        if ~state.verifiedSafetyLive
            receiver=dreProjectCodeAidedReplayDecode(frame.observation,config);
            live=uint16([sum(receiver.detectedPhysicalBins~= ...
                frame.truth.payloadPhysicalBins),sum( ...
                receiver.hardDecodedDataBits(:)~=frame.truth.dataBits(:))]);
            if ~isequal(live,state.errors(packetIndex,:))
                error('DRE:CodeAidedSafetyMismatch', ...
                    'Live safety branch differs from frozen Stage55 V16.');
            end
            state.verifiedSafetyLive=true;
        end
    else
        receiver=dreProjectCodeAidedReplayDecode(frame.observation,config);
        if receiver.usesPayloadTruth || receiver.usesOrbitTruth || ...
                receiver.usesSnrInput || receiver.knownMidamblesUsed~=0 || ...
                ~strcmp(receiver.receiverMode,'code-aided-dynamic')
            error('DRE:CodeAidedTruth','Receiver used prohibited information.');
        end
        state.errors(packetIndex,1)=uint16(sum( ...
            receiver.detectedPhysicalBins~=frame.truth.payloadPhysicalBins));
        state.errors(packetIndex,2)=uint16(sum( ...
            receiver.hardDecodedDataBits(:)~=frame.truth.dataBits(:)));
        state.replayPackets=state.replayPackets+1;
    end
    state.fingerprintsVerified(packetIndex)=true;
    state.completed=packetIndex;
    if mod(packetIndex,25)==0 || packetIndex==n
        savedSignature=cellSignature; %#ok<NASGU>
        tempPath=[checkpoint '.tmp'];
        save(tempPath,'state','savedSignature','-v7.3');
        movefile(tempPath,checkpoint,'f');
        fprintf('Code-aided Case2 SNR %+g: %d/%d\n',snrDb,packetIndex,n);
    end
end
if ~all(state.fingerprintsVerified)
    error('DRE:CodeAidedPairing','Not every IQ fingerprint was verified.');
end
cellResult=struct('status','COMPLETE','signature',cellSignature, ...
    'caseIndex',ci,'snrDb',snrDb,'packetCount',n, ...
    'errors',state.errors,'fingerprintsVerified',state.fingerprintsVerified, ...
    'staticPackets',state.staticPackets,'safetyPackets',state.safetyPackets, ...
    'replayPackets',state.replayPackets, ...
    'dynamicPackets',n-state.staticPackets,'reusedFrozenStaticBranch',false);
save(cellPath,'cellResult','-v7.3');
end

function key=localKey(ci,si,snrDb,packetIndex)
key=struct('planVersion','unified-v16-test','phase','paired-grid', ...
    'track','B-method-aligned','channel','AWGN', ...
    'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
    'replicateId',packetIndex,'packetId',packetIndex, ...
    'eventType','paired-frame','eventIndex',ci*100+si,'sampleIndex',0);
end

function summary=localBuildTable(cells,formalCells,config)
rowCount=20*3;caseIndex=zeros(rowCount,1);snrDb=zeros(rowCount,1);
methodId=strings(rowCount,1);methodLabel=strings(rowCount,1);
packetCount=1000*ones(rowCount,1);symbolErrors=zeros(rowCount,1);
symbolCount=112000*ones(rowCount,1);ser=zeros(rowCount,1);
bitErrors=zeros(rowCount,1);bitCount=768000*ones(rowCount,1);ber=zeros(rowCount,1);
row=0;
for index=1:20
    candidate=double(cells(index).errors);
    baselines=double(squeeze(formalCells(index).errors(:,2:3,:)));
    errors=cat(2,reshape(candidate,1000,1,2),baselines);
    for method=1:3
        row=row+1;caseIndex(row)=cells(index).caseIndex;snrDb(row)=cells(index).snrDb;
        methodId(row)=string(config.methodIds{method});
        methodLabel(row)=string(config.methodLabels{method});
        symbolErrors(row)=sum(errors(:,method,1));
        bitErrors(row)=sum(errors(:,method,2));
        ser(row)=symbolErrors(row)/symbolCount(row);ber(row)=bitErrors(row)/bitCount(row);
    end
end
summary=table(caseIndex,snrDb,methodId,methodLabel,packetCount, ...
    symbolErrors,symbolCount,ser,bitErrors,bitCount,ber);
end

function localWriteArtifacts(t,config,output)
writetable(t,fullfile(output,'case1_case2_code_aided_ser_v3.csv'));
for ci=1:2
    fig=figure('Visible','off','Color','w','Position',[100 100 1180 650]);
    axesHandle=axes(fig);set(axesHandle,'YScale','log');hold(axesHandle,'on');
    handles=gobjects(3,1);colors=[0 0.45 0.74;0.85 0.325 0.098;0.93 0.69 0.13];
    for method=[2 3 1]
        rows=t.caseIndex==ci & t.methodId==string(config.methodIds{method});
        values=max(t.ser(rows),0.5./t.symbolCount(rows));
        if method==1
            handles(method)=plot(axesHandle,t.snrDb(rows),values,'x--', ...
                'Color',colors(method,:),'LineWidth',1.5,'MarkerSize',8);
        else
            handles(method)=plot(axesHandle,t.snrDb(rows),values,'o-', ...
                'Color',colors(method,:),'LineWidth',1.7,'MarkerSize',6);
        end
    end
    grid(axesHandle,'on');xlim(axesHandle,[-30 -21]);ylim(axesHandle,[1e-5 1.2]);
    xlabel(axesHandle,'SNR (dB)');ylabel(axesHandle,'SER (log scale)');
    title(axesHandle,sprintf('Case %d: no-midamble robust replay vs baselines',ci));
    legend(axesHandle,handles,config.methodLabels,'Location','eastoutside');
    if ci==1
        text(axesHandle,0.01,0.75, ...
            'Robust replay and Stage55 share the observable static branch', ...
            'Units','normalized','FontSize',9,'Color',[0.2 0.2 0.2]);
    end
    exportgraphics(fig,fullfile(output,sprintf('Case%d_code_aided_SER_v3.png',ci)), ...
        'Resolution',220);close(fig);
end
end

function value=localSha256(path)
file=fopen(path,'rb');
if file<0,error('DRE:SourceMissing','Source file not found: %s',path);end
closer=onCleanup(@()fclose(file));bytes=fread(file,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');digest.update(bytes);
raw=typecast(digest.digest(),'uint8');value=lower(reshape(dec2hex(raw,2).',1,[]));
end
