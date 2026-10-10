function result = run_refined_lr_v1_comparison()
%RUN_REFINED_LR_V1_COMPARISON Minimal receiver-only LR refinement check.
%   First 150 paired packets per case are development; the remaining 850
%   are untouched validation. No new pilots, orbit truth, or payload truth.

root = dreSetupPaths(true);
base = load(fullfile(root,'results','project_formal_v23_verified', ...
    'project_formal_v23.mat'),'result');
aligned = load(fullfile(root,'results','project_centroid10_alignment_v4', ...
    'centroid10_alignment.mat'),'result');
base = base.result;aligned = aligned.result;
if ~strcmp(base.status,'COMPLETE') || ~strcmp(aligned.status,'COMPLETE') || ...
        ~strcmp(aligned.baseSignature,base.signature)
    error('DRE:RefinedBase','Verified ten-point paired results are required.');
end
files = {fullfile(root,'scripts','run_refined_lr_v1_comparison.m'); ...
    fullfile(root,'src','dreEstimatePaperCentroids10.m'); ...
    fullfile(root,'src','dreDecodeRefinedAdaptiveLR.m'); ...
    fullfile(root,'src','dreProjectRefinedLRDecode.m'); ...
    fullfile(root,'src','dreDecodeProjectHardBits.m')};
hashes = strings(numel(files),2);
for k=1:numel(files)
    hashes(k,:) = [string(files{k}),string(localSha256(files{k}))];
end
config = base.config;
config.identity = 'dietl-ten-point-refined-lr-v1-minus21';
methodIds = { ...
    'paper-ols8';'receiver-ols16';'receiver-theilsen8'};
methodLabels = { ...
    'Paper ten-point OLS H8';'OLS H16';'Theil-Sen H8'};
developmentPackets = 150;
signature = dreConfigurationSignature(struct('config',config, ...
    'baseSignature',base.signature,'alignedSignature',aligned.signature, ...
    'hashes',hashes,'methodIds',{methodIds}, ...
    'developmentPackets',developmentPackets));
output = fullfile(root,'results','refined_lr_v1');
if ~isfolder(output),mkdir(output);end
matPath = fullfile(output,'refined_lr_v1.mat');
if isfile(matPath)
    cached=load(matPath,'result');
    if ~strcmp(cached.result.signature,signature)
        error('DRE:RefinedCache','Existing result has another source identity.');
    end
    result=cached.result;
    localWriteSidecars(result.table,output);
    return
end

centroidConfig=struct('samplesPerSymbol',config.v4.samplesPerSymbol, ...
    'zeroPaddingFactor',4);
caseResults=cell(2,1);
for ci=1:2
    sourceIndex=find([base.cells.caseIndex]==ci & ...
        [base.cells.snrDb]==-21,1);
    source=base.cells(sourceIndex);
    old=aligned.cases(ci);
    if source.packetCount~=1000 || old.packetCount~=1000 || ...
            ~all(old.fingerprintsVerified)
        error('DRE:RefinedSourceCell','Incomplete -21 dB source cell.');
    end
    errors=zeros(1000,3,2,'uint16');
    errors(:,1,:)=old.errors(:,3,:);
    matched=false(1000,1);
    for packetIndex=1:1000
        key=struct('planVersion','unified-v16-test','phase','paired-grid', ...
            'track','B-method-aligned','channel','AWGN', ...
            'comparisonMode','case-anchor-controlled','snrDb',-21, ...
            'replicateId',packetIndex,'packetId',packetIndex, ...
            'eventType','paired-frame','eventIndex',ci*100+10, ...
            'sampleIndex',0);
        ledger=v4EventRandomLedger(config.randomSeedRoot,key);
        frame=v4GenerateBCaseAnchorFrame(config.v4, ...
            config.caseStartTimeSec(ci),-21,ledger);
        if ~isequal(frame.observation.sampleFingerprint, ...
                source.fingerprints(packetIndex,:))
            error('DRE:RefinedFrameMismatch','IQ changed from frozen V23.');
        end
        matched(packetIndex)=true;
        selected=[frame.observation.layout.bootstrapRows; ...
            frame.observation.layout.dataRows];
        centroid=dreEstimatePaperCentroids10( ...
            frame.observation.rxPhysical(selected,:),centroidConfig);
        candidates={ ...
            dreProjectRefinedLRDecode(frame.observation,config, ...
                16,'ordinary',centroid.rawBins), ...
            dreProjectRefinedLRDecode(frame.observation,config, ...
                8,'theil-sen',centroid.rawBins)};
        for candidate=1:2
            rx=candidates{candidate};
            if rx.usesPayloadTruth || rx.usesOrbitTruth || ...
                    rx.knownMidamblesUsed~=0
                error('DRE:RefinedTruth','Receiver contract violated.');
            end
            method=candidate+1;
            errors(packetIndex,method,1)=uint16(sum( ...
                rx.detectedPhysicalBins~=frame.truth.payloadPhysicalBins));
            errors(packetIndex,method,2)=uint16(sum( ...
                rx.hardDecodedDataBits(:)~=frame.truth.dataBits(:)));
        end
        if mod(packetIndex,100)==0
            fprintf('Refined LR case %d -21 dB: %d/1000 frames\n', ...
                ci,packetIndex);
        end
    end
    caseResults{ci}=struct('caseIndex',ci,'snrDb',-21, ...
        'packetCount',1000,'errors',errors,'fingerprintsVerified',matched);
end
caseResults=vertcat(caseResults{:});

developmentErrors=zeros(1,3);
for ci=1:2
    developmentErrors=developmentErrors+ ...
        reshape(sum(double(caseResults(ci).errors(1:developmentPackets,:,1)),1),1,3);
end
[~,selectedIndex]=min(developmentErrors);
summary=localBuildTable(caseResults,methodIds,methodLabels, ...
    developmentPackets);
result=struct('status','COMPLETE','signature',signature, ...
    'baseSignature',base.signature,'alignedSignature',aligned.signature, ...
    'config',config,'sourceHashes',hashes,'methodIds',{methodIds}, ...
    'methodLabels',{methodLabels},'developmentPackets',developmentPackets, ...
    'selectedMethodId',methodIds{selectedIndex}, ...
    'selectionCriterion','Lowest pooled development SER across both cases', ...
    'cases',caseResults,'table',summary,'pairedFrames',true);
save(matPath,'result','-v7.3');
localWriteSidecars(summary,output);
end

function summary=localBuildTable(cases,methodIds,methodLabels,devN)
rows=18;
caseIndex=zeros(rows,1);subset=strings(rows,1);methodId=strings(rows,1);
methodLabel=strings(rows,1);packetCount=zeros(rows,1);
symbolErrors=zeros(rows,1);symbolCount=zeros(rows,1);
bitErrors=zeros(rows,1);bitCount=zeros(rows,1);
ser=zeros(rows,1);ber=zeros(rows,1);
serLow95=zeros(rows,1);serHigh95=zeros(rows,1);
berLow95=zeros(rows,1);berHigh95=zeros(rows,1);
baselineMinusMethodSer=zeros(rows,1);
baselineMinusMethodSerLow95=zeros(rows,1);
baselineMinusMethodSerHigh95=zeros(rows,1);
row=0;
for ci=1:2
    e=double(cases(ci).errors);
    subsets={1:devN,devN+1:1000,1:1000};
    names=["development","validation","all"];
    for si=1:3
        indices=subsets{si};n=numel(indices);
        stream=RandStream('mt19937ar','Seed',946400000+ci*10+si);
        bootSer=zeros(2000,3);bootBer=zeros(2000,3);
        for draw=1:2000
            sample=indices(randi(stream,n,n,1));
            bootSer(draw,:)=sum(e(sample,:,1),1)/(n*112);
            bootBer(draw,:)=sum(e(sample,:,2),1)/(n*768);
        end
        serBounds=prctile(bootSer,[2.5 97.5],1);
        berBounds=prctile(bootBer,[2.5 97.5],1);
        for mi=1:3
            row=row+1;
            caseIndex(row)=ci;subset(row)=names(si);
            methodId(row)=string(methodIds{mi});
            methodLabel(row)=string(methodLabels{mi});
            packetCount(row)=n;
            symbolErrors(row)=sum(e(indices,mi,1));
            symbolCount(row)=n*112;
            bitErrors(row)=sum(e(indices,mi,2));
            bitCount(row)=n*768;
            ser(row)=symbolErrors(row)/symbolCount(row);
            ber(row)=bitErrors(row)/bitCount(row);
            serLow95(row)=serBounds(1,mi);serHigh95(row)=serBounds(2,mi);
            berLow95(row)=berBounds(1,mi);berHigh95(row)=berBounds(2,mi);
            baselineMinusMethodSer(row)= ...
                (sum(e(indices,1,1))-sum(e(indices,mi,1)))/symbolCount(row);
            difference=bootSer(:,1)-bootSer(:,mi);
            bounds=prctile(difference,[2.5 97.5]);
            baselineMinusMethodSerLow95(row)=bounds(1);
            baselineMinusMethodSerHigh95(row)=bounds(2);
        end
    end
end
summary=table(caseIndex,subset,methodId,methodLabel,packetCount, ...
    symbolErrors,symbolCount,bitErrors,bitCount,ser,serLow95,serHigh95, ...
    ber,berLow95,berHigh95,baselineMinusMethodSer, ...
    baselineMinusMethodSerLow95,baselineMinusMethodSerHigh95);
end

function localWriteSidecars(t,output)
writetable(t,fullfile(output,'refined_lr_v1_summary.csv'));
figure('Visible','off','Color','w','Position',[100 100 960 500]);
for ci=1:2
    subplot(1,2,ci);
    rows=t.caseIndex==ci & t.subset=="validation";
    bar(t.ser(rows));
    xticks(1:3);xticklabels({'Paper H8','OLS H16','Theil-Sen H8'});
    ylabel('SER');ylim([0 1]);grid on;
    title(sprintf('Case %d, -21 dB, 850 validation packets',ci));
end
exportgraphics(gcf,fullfile(output,'refined_lr_v1_validation.png'), ...
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
