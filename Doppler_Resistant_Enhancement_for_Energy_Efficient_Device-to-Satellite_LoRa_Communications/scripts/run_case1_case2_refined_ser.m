function result = run_case1_case2_refined_ser()
%RUN_CASE1_CASE2_REFINED_SER Paired V4 SER-SNR figures for two orbit cases.
%   Six receivers share each 1000-packet V23 cell. The first three methods
%   reuse frozen per-packet records; Dietl H8, OLS H16, and Theil-Sen H8
%   use the ten-point centroid without midamble feedback.

root = dreSetupPaths(true);
formal = load(fullfile(root,'results','project_formal_v23_verified', ...
    'project_formal_v23.mat'),'result');
refined = load(fullfile(root,'results','refined_lr_v1', ...
    'refined_lr_v1.mat'),'result');
alignment = load(fullfile(root,'results','project_centroid10_alignment_v4', ...
    'centroid10_alignment.mat'),'result');
formal = formal.result;refined = refined.result;alignment = alignment.result;
if ~strcmp(formal.status,'COMPLETE') || ...
        ~strcmp(refined.status,'COMPLETE') || ...
        ~strcmp(alignment.status,'COMPLETE') || ...
        ~strcmp(refined.baseSignature,formal.signature) || ...
        ~strcmp(alignment.baseSignature,formal.signature) || ...
        numel(formal.cells)~=20
    error('DRE:SerCurveSource','Verified V23 paired sources are required.');
end
for k=1:size(formal.sourceHashes,1)
    if ~strcmp(formal.sourceHashes(k,2), ...
            localSha256(char(formal.sourceHashes(k,1))))
        error('DRE:SerCurveV4Changed','V4 dependency changed after the base run.');
    end
end
config = formal.config;
config.identity = 'dietl-refined-case1-case2-ser-snr-v1';
config.methodIds = {'huang-prec-unified-v9', ...
    'stage55-unified-v16','paper-midamble-adapted-v6', ...
    'dietl-paper-centroid10-h8','dietl-ols-h16','dietl-theilsen-h8'};
config.methodLabels = {'Huang V9','Stage55 V16','Midamble V6', ...
    'Dietl paper H8','Dietl OLS H16','Dietl Theil-Sen H8'};
ownFiles = {fullfile(root,'scripts','run_case1_case2_refined_ser.m'); ...
    fullfile(root,'src','dreEstimatePaperCentroids10.m'); ...
    fullfile(root,'src','dreProjectPaperExact10Decode.m'); ...
    fullfile(root,'src','dreProjectRefinedLRDecode.m'); ...
    fullfile(root,'src','dreDecodeRefinedAdaptiveLR.m'); ...
    fullfile(root,'src','dreDecodeProjectHardBits.m')};
ownHashes = strings(numel(ownFiles),2);
for k=1:numel(ownFiles)
    ownHashes(k,:) = [string(ownFiles{k}), ...
        string(localSha256(ownFiles{k}))];
end
signature = dreConfigurationSignature(struct('config',config, ...
    'formalSignature',formal.signature, ...
    'refinedSignature',refined.signature, ...
    'alignmentSignature',alignment.signature, ...
    'sourceHashes',ownHashes));
output = fullfile(root,'results','case1_case2_refined_ser');
if ~isfolder(output),mkdir(output);end
matPath = fullfile(output,'case1_case2_refined_ser.mat');
if isfile(matPath)
    cached = load(matPath,'result');
    if ~strcmp(cached.result.signature,signature)
        error('DRE:SerCurveSignature','Existing result has another signature.');
    end
    result = cached.result;
    localWriteSidecars(result.table,result.config,output);
    return
end

cells = cell(20,1);
for ci=1:2
    for si=1:10
        index=(ci-1)*10+si;
        source=formal.cells(index);
        if source.caseIndex~=ci || source.snrDb~=config.snrDb(si)
            error('DRE:SerCurveOrder','Frozen V23 cells are out of order.');
        end
        cells{index}=localRunCell(source,refined,alignment,config, ...
            ci,si,signature,output);
    end
end
cells=vertcat(cells{:});
summary=localBuildTable(cells,config);
result=struct('status','COMPLETE','signature',signature, ...
    'config',config,'formalSignature',formal.signature, ...
    'refinedSignature',refined.signature, ...
    'alignmentSignature',alignment.signature, ...
    'sourceHashes',ownHashes,'cells',cells,'table',summary, ...
    'pairedFrames',true,'packetCountPerCell',1000);
save(matPath,'result','-v7.3');
localWriteSidecars(summary,config,output);
end

function cellResult=localRunCell(source,refined,alignment,config, ...
        ci,si,parentSignature,output)
snrDb=config.snrDb(si);
folder=fullfile(output,'cells',sprintf('case%d',ci), ...
    sprintf('snr_%+03d',snrDb));
if ~isfolder(folder),mkdir(folder);end
cellPath=fullfile(folder,'cell.mat');
checkpointPath=fullfile(folder,'checkpoint.mat');
cellSignature=dreConfigurationSignature(struct('parent',parentSignature, ...
    'sourceCell',source.signature,'caseIndex',ci,'snrDb',snrDb));
if isfile(cellPath)
    cached=load(cellPath,'cellResult');
    if ~strcmp(cached.cellResult.signature,cellSignature)
        error('DRE:SerCurveCellSignature','Cell identity mismatch.');
    end
    cellResult=cached.cellResult;
    fprintf('Reusing SER cell Case%d SNR %+g.\n',ci,snrDb);
    return
end
n=1000;
if isfile(checkpointPath)
    saved=load(checkpointPath,'state','savedSignature');
    if ~strcmp(saved.savedSignature,cellSignature)
        error('DRE:SerCurveCheckpoint','Checkpoint identity changed.');
    end
    state=saved.state;
else
    state=struct('completed',0,'errors',zeros(n,6,2,'uint16'), ...
        'fingerprintsVerified',false(n,1));
    state.errors(:,1:3,:)=source.errors(:,1:3,:);
end
if snrDb==-21
    baseline=alignment.cases(ci);
    refinedCase=refined.cases(ci);
    if ~all(baseline.fingerprintsVerified) || ...
            ~all(refinedCase.fingerprintsVerified) || ...
            ~isequal(baseline.errors(:,3,:),refinedCase.errors(:,1,:))
        error('DRE:SerCurveMinus21','Previously tested -21 dB records mismatch.');
    end
    state.errors(:,4,:)=baseline.errors(:,3,:);
    state.errors(:,5:6,:)=refinedCase.errors(:,2:3,:);
    state.fingerprintsVerified(:)=true;
    state.completed=n;
else
    centroidConfig=struct('samplesPerSymbol',config.v4.samplesPerSymbol, ...
        'zeroPaddingFactor',4);
    for packetIndex=state.completed+1:n
        key=struct('planVersion','unified-v16-test','phase','paired-grid', ...
            'track','B-method-aligned','channel','AWGN', ...
            'comparisonMode','case-anchor-controlled','snrDb',snrDb, ...
            'replicateId',packetIndex,'packetId',packetIndex, ...
            'eventType','paired-frame','eventIndex',ci*100+si, ...
            'sampleIndex',0);
        ledger=v4EventRandomLedger(config.randomSeedRoot,key);
        frame=v4GenerateBCaseAnchorFrame(config.v4, ...
            config.caseStartTimeSec(ci),snrDb,ledger);
        if ~isequal(frame.observation.sampleFingerprint, ...
                source.fingerprints(packetIndex,:))
            error('DRE:SerCurveFrame','Regenerated IQ differs from V23.');
        end
        state.fingerprintsVerified(packetIndex)=true;
        selected=[frame.observation.layout.bootstrapRows; ...
            frame.observation.layout.dataRows];
        centroid=dreEstimatePaperCentroids10( ...
            frame.observation.rxPhysical(selected,:),centroidConfig);
        receivers={ ...
            dreProjectPaperExact10Decode(frame.observation,config, ...
                'adaptive',centroid.rawBins), ...
            dreProjectRefinedLRDecode(frame.observation,config, ...
                16,'ordinary',centroid.rawBins), ...
            dreProjectRefinedLRDecode(frame.observation,config, ...
                8,'theil-sen',centroid.rawBins)};
        for method=4:6
            rx=receivers{method-3};
            if rx.usesPayloadTruth || rx.usesOrbitTruth || ...
                    rx.knownMidamblesUsed~=0
                error('DRE:SerCurveTruth','Receiver accessed truth or midambles.');
            end
            state.errors(packetIndex,method,1)=uint16(sum( ...
                rx.detectedPhysicalBins~=frame.truth.payloadPhysicalBins));
            state.errors(packetIndex,method,2)=uint16(sum( ...
                rx.hardDecodedDataBits(:)~=frame.truth.dataBits(:)));
        end
        state.completed=packetIndex;
        if mod(packetIndex,25)==0 || packetIndex==n
            savedSignature=cellSignature; %#ok<NASGU>
            tempPath=[checkpointPath '.tmp'];
            save(tempPath,'state','savedSignature','-v7.3');
            movefile(tempPath,checkpointPath,'f');
            fprintf('SER curves Case%d SNR %+g: %d/%d frames\n', ...
                ci,snrDb,packetIndex,n);
        end
    end
end
if ~all(state.fingerprintsVerified)
    error('DRE:SerCurvePairing','Not all IQ frames were verified.');
end
cellResult=struct('status','COMPLETE','signature',cellSignature, ...
    'sourceCellSignature',source.signature,'caseIndex',ci,'snrDb',snrDb, ...
    'packetCount',n,'errors',state.errors, ...
    'fingerprintsVerified',state.fingerprintsVerified);
save(cellPath,'cellResult','-v7.3');
end

function summary=localBuildTable(cells,config)
count=numel(cells)*numel(config.methodIds);
caseIndex=zeros(count,1);snrDb=zeros(count,1);
methodId=strings(count,1);methodLabel=strings(count,1);
packetCount=1000*ones(count,1);
symbolErrors=zeros(count,1);symbolCount=112000*ones(count,1);
bitErrors=zeros(count,1);bitCount=768000*ones(count,1);
ser=zeros(count,1);serLow95=zeros(count,1);serHigh95=zeros(count,1);
ber=zeros(count,1);berLow95=zeros(count,1);berHigh95=zeros(count,1);
row=0;
for index=1:numel(cells)
    e=double(cells(index).errors);
    stream=RandStream('mt19937ar','Seed', ...
        946700000+cells(index).caseIndex*100+round(cells(index).snrDb+100));
    bootSer=zeros(2000,6);bootBer=zeros(2000,6);
    for draw=1:2000
        sample=randi(stream,1000,1000,1);
        bootSer(draw,:)=sum(e(sample,:,1),1)/112000;
        bootBer(draw,:)=sum(e(sample,:,2),1)/768000;
    end
    boundsSer=prctile(bootSer,[2.5 97.5],1);
    boundsBer=prctile(bootBer,[2.5 97.5],1);
    for method=1:6
        row=row+1;
        caseIndex(row)=cells(index).caseIndex;
        snrDb(row)=cells(index).snrDb;
        methodId(row)=string(config.methodIds{method});
        methodLabel(row)=string(config.methodLabels{method});
        symbolErrors(row)=sum(e(:,method,1));
        bitErrors(row)=sum(e(:,method,2));
        ser(row)=symbolErrors(row)/symbolCount(row);
        ber(row)=bitErrors(row)/bitCount(row);
        serLow95(row)=boundsSer(1,method);
        serHigh95(row)=boundsSer(2,method);
        berLow95(row)=boundsBer(1,method);
        berHigh95(row)=boundsBer(2,method);
    end
end
summary=table(caseIndex,snrDb,methodId,methodLabel,packetCount, ...
    symbolErrors,symbolCount,ser,serLow95,serHigh95, ...
    bitErrors,bitCount,ber,berLow95,berHigh95);
end

function localWriteSidecars(t,config,output)
writetable(t,fullfile(output,'case1_case2_ser_summary.csv'));
for ci=1:2
    figure('Visible','off','Color','w','Position',[100 100 1050 620]);
    hold on;
    for method=1:6
        rows=t.caseIndex==ci & ...
            t.methodId==string(config.methodIds{method});
        % Zero-error points need a display floor on the logarithmic axis.
        values=max(t.ser(rows),0.5./t.symbolCount(rows));
        semilogy(t.snrDb(rows),values,'o-','LineWidth',1.5, ...
            'MarkerSize',6);
    end
    grid on;
    xlim([min(config.snrDb) max(config.snrDb)]);
    ylim([1e-5 1]);
    xlabel('SNR (dB)');ylabel('SER');
    title(sprintf('Case %d: SF12, 125 kHz, 1000 paired packets/SNR',ci));
    legend(config.methodLabels,'Location','eastoutside');
    text(0.01,0.01,'Zero errors shown at 0.5 / symbol count', ...
        'Units','normalized','FontSize',8,'Color',[0.3 0.3 0.3]);
    exportgraphics(gcf,fullfile(output,sprintf('Case%d_SER_vs_SNR.png',ci)), ...
        'Resolution',220);
    close(gcf);
end
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
