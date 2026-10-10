function result = run_project_centroid10_alignment()
%RUN_PROJECT_CENTROID10_ALIGNMENT Two-factor check at project SNR -21 dB.
%   Factor 1: the prior 21-point versus literal ten-point centroid.
%   Factor 2: ignoring versus using existing receiver-known V4 midambles.
%   All four outcomes use the exact same 1000 IQ frames per case.

root = dreSetupPaths(true);
b = load(fullfile(root,'results','project_formal_v23_verified', ...
    'project_formal_v23.mat'),'result');
v = load(fullfile(root,'results','project_paper_flow_v2', ...
    'project_paper_flow_v2.mat'),'result');
base = b.result; previous = v.result;
if ~strcmp(base.status,'COMPLETE') || ~strcmp(previous.status,'COMPLETE') || ...
        ~strcmp(previous.baseSignature,base.signature)
    error('DRE:CentroidBase','Verified paired source results are required.');
end
allHashes = [base.sourceHashes;previous.sourceHashes];
for k=1:size(allHashes,1)
    if ~strcmp(allHashes(k,2),localSha256(char(allHashes(k,1))))
        error('DRE:CentroidSourceChanged','A paired source dependency changed.');
    end
end
sourceFiles = { ...
    fullfile(root,'scripts','run_project_centroid10_alignment.m'); ...
    fullfile(root,'src','dreEstimatePaperCentroids10.m'); ...
    fullfile(root,'src','dreProjectPaperExact10Decode.m'); ...
    fullfile(root,'src','dreProjectLinearRegressionDecode.m'); ...
    fullfile(root,'src','dreProjectPaperFlowDecode.m')};
sourceHashes = strings(numel(sourceFiles),2);
for k=1:numel(sourceFiles)
    sourceHashes(k,:) = [string(sourceFiles{k}), ...
        string(localSha256(sourceFiles{k}))];
end
config = base.config;
config.identity = 'dietl-centroid-ten-vs-twentyone-project-minus21';
identity = struct('config',config,'baseSignature',base.signature, ...
    'paperFlowSignature',previous.signature,'sourceHashes',sourceHashes);
signature = dreConfigurationSignature(identity);
output = fullfile(root,'results','project_centroid10_alignment_v4');
if ~isfolder(output),mkdir(output);end
matPath = fullfile(output,'centroid10_alignment.mat');
if isfile(matPath)
    saved = load(matPath,'result');
    if ~strcmp(saved.result.signature,signature)
        error('DRE:CentroidCache','Existing result has another signature.');
    end
    result = saved.result;
    localWriteSidecars(result.table,output);
    return
end

centroidConfig = struct('samplesPerSymbol',config.v4.samplesPerSymbol, ...
    'zeroPaddingFactor',4);
caseCells = cell(2,1);
for caseIndex=1:2
    match = find([base.cells.caseIndex]==caseIndex & ...
        [base.cells.snrDb]==-21,1);
    matchPrevious = find([previous.cells.caseIndex]==caseIndex & ...
        [previous.cells.snrDb]==-21,1);
    if isempty(match) || isempty(matchPrevious)
        error('DRE:CentroidCell','The -21 dB paired cell is missing.');
    end
    baseCell = base.cells(match);
    v2Cell = previous.cells(matchPrevious);
    n = baseCell.packetCount;
    if n~=1000 || v2Cell.packetCount~=n || ...
            ~isequal(v2Cell.errors(:,1:5,:),baseCell.errors)
        error('DRE:CentroidPairing','The old-method records are not paired.');
    end
    errors = zeros(n,4,2,'uint16');
    errors(:,1,:) = baseCell.errors(:,5,:);
    errors(:,2,:) = v2Cell.errors(:,7,:);
    matched = false(n,1);
    for packetIndex=1:n
        key = struct('planVersion','unified-v16-test','phase','paired-grid', ...
            'track','B-method-aligned','channel','AWGN', ...
            'comparisonMode','case-anchor-controlled','snrDb',-21, ...
            'replicateId',packetIndex,'packetId',packetIndex, ...
            'eventType','paired-frame','eventIndex',caseIndex*100+10, ...
            'sampleIndex',0);
        ledger = v4EventRandomLedger(config.randomSeedRoot,key);
        frame = v4GenerateBCaseAnchorFrame(config.v4, ...
            config.caseStartTimeSec(caseIndex),-21,ledger);
        if ~isequal(frame.observation.sampleFingerprint, ...
                baseCell.fingerprints(packetIndex,:))
            error('DRE:CentroidFrame','Regenerated IQ does not match source.');
        end
        matched(packetIndex) = true;
        estimate = dreEstimatePaperCentroids10( ...
            frame.observation.rxPhysical,centroidConfig);
        rows = [frame.observation.layout.bootstrapRows; ...
            frame.observation.layout.dataRows];
        plain = dreProjectPaperExact10Decode( ...
            frame.observation,config,'adaptive',estimate.rawBins(rows));
        known = dreProjectPaperFlowDecode( ...
            frame.observation,config,'adaptive',estimate.rawBins);
        receivers = {plain,known};
        for branch=1:2
            rx = receivers{branch};
            if rx.usesPayloadTruth || rx.usesOrbitTruth
                error('DRE:CentroidTruth','Truth leaked to the receiver.');
            end
            col = branch+2;
            errors(packetIndex,col,1) = uint16(sum( ...
                rx.detectedPhysicalBins~=frame.truth.payloadPhysicalBins));
            errors(packetIndex,col,2) = uint16(sum( ...
                rx.hardDecodedDataBits(:)~=frame.truth.dataBits(:)));
        end
        if mod(packetIndex,100)==0
            fprintf('10-point centroid case %d SNR -21: %d/%d frames\n', ...
                caseIndex,packetIndex,n);
        end
    end
    caseCells{caseIndex} = struct('caseIndex',caseIndex, ...
        'snrDb',-21,'packetCount',n,'errors',errors, ...
        'fingerprintsVerified',matched);
end
caseResults = vertcat(caseCells{:});
summary = localBuildTable(caseResults,config);
result = struct('status','COMPLETE','signature',signature, ...
    'baseSignature',base.signature,'paperFlowSignature',previous.signature, ...
    'config',config,'sourceHashes',sourceHashes, ...
    'cases',caseResults,'table',summary,'pairedFrames',true, ...
    'centroidPoints',10,'notes', ...
    'Even ten-point window uses four FFT samples below and five above peak.');
save(matPath,'result','-v7.3');
localWriteSidecars(summary,output);
end

function summary = localBuildTable(cases,config)
labels = ["21 points, no midambles";"21 points, known midambles"; ...
    "10 points, no midambles";"10 points, known midambles"];
caseIndex = zeros(8,1); snrDb = -21*ones(8,1);
method = strings(8,1);packetCount = 1000*ones(8,1);
symbolErrors = zeros(8,1);symbolCount = 112000*ones(8,1);
bitErrors = zeros(8,1);bitCount = 768000*ones(8,1);
ser = zeros(8,1);ber = zeros(8,1);
serLow95=zeros(8,1);serHigh95=zeros(8,1);
berLow95=zeros(8,1);berHigh95=zeros(8,1);
oldMinusNewSer=zeros(8,1);oldMinusNewSerLow95=zeros(8,1);
oldMinusNewSerHigh95=zeros(8,1);
for ci=1:2
    e=double(cases(ci).errors);
    stream=RandStream('mt19937ar','Seed',946300000+ci);
    bootSer=zeros(2000,4);bootBer=zeros(2000,4);
    for draw=1:2000
        sample=randi(stream,1000,1000,1);
        bootSer(draw,:)=sum(e(sample,:,1),1)/112000;
        bootBer(draw,:)=sum(e(sample,:,2),1)/768000;
    end
    boundsSer=prctile(bootSer,[2.5 97.5],1);
    boundsBer=prctile(bootBer,[2.5 97.5],1);
    boundsDiff=prctile(bootSer(:,1)-bootSer(:,3),[2.5 97.5]);
    for j=1:4
        row=(ci-1)*4+j;
        caseIndex(row)=ci;method(row)=labels(j);
        symbolErrors(row)=sum(e(:,j,1));
        bitErrors(row)=sum(e(:,j,2));
        ser(row)=symbolErrors(row)/symbolCount(row);
        ber(row)=bitErrors(row)/bitCount(row);
        serLow95(row)=boundsSer(1,j);serHigh95(row)=boundsSer(2,j);
        berLow95(row)=boundsBer(1,j);berHigh95(row)=boundsBer(2,j);
        oldMinusNewSer(row)= ...
            (sum(e(:,1,1))-sum(e(:,3,1)))/symbolCount(row);
        oldMinusNewSerLow95(row)=boundsDiff(1);
        oldMinusNewSerHigh95(row)=boundsDiff(2);
    end
end
summary=table(caseIndex,snrDb,method,packetCount, ...
    symbolErrors,symbolCount,bitErrors,bitCount,ser,serLow95,serHigh95, ...
    ber,berLow95,berHigh95,oldMinusNewSer, ...
    oldMinusNewSerLow95,oldMinusNewSerHigh95);
end

function localWriteSidecars(summary,output)
writetable(summary,fullfile(output,'centroid10_alignment.csv'));
figure('Visible','off','Color','w','Position',[100 100 1050 600]);
tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
for ci=1:2
    nexttile;
    rows=summary.caseIndex==ci;
    values=summary.ser(rows);
    bar(1:4,values);
    xticks(1:4);xticklabels({'21/no mid','21/known mid', ...
        '10/no mid','10/known mid'});
    ylabel('SER');ylim([0 1]);grid on;
    title(sprintf('Case %d, -21 dB, 1000 paired packets',ci));
end
exportgraphics(gcf,fullfile(output,'centroid10_alignment.png'), ...
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
