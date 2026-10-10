function result = run_refined_lr_independent_holdout()
%RUN_REFINED_LR_INDEPENDENT_HOLDOUT Fresh V4 frames, packet IDs 1001:2000.
%   Compare the paper ten-point H8 receiver with two simple receiver-only
%   line fits. No candidate was selected using these seeds before this run.

root=dreSetupPaths(true);
config=dreProjectConfig();config.v4=sf12NoLdroSf11FlowConfig();
config.identity='dietl-refined-lr-independent-holdout-v1';
firstPacketId=1001;lastPacketId=2000;
files={fullfile(root,'scripts','run_refined_lr_independent_holdout.m'); ...
    fullfile(root,'src','dreEstimatePaperCentroids10.m'); ...
    fullfile(root,'src','dreProjectPaperExact10Decode.m'); ...
    fullfile(root,'src','dreDecodeRefinedAdaptiveLR.m'); ...
    fullfile(root,'src','dreProjectRefinedLRDecode.m'); ...
    fullfile(root,'src','dreDecodeProjectHardBits.m')};
sourceHashes=strings(numel(files),2);
for k=1:numel(files)
    sourceHashes(k,:)=[string(files{k}),string(localSha256(files{k}))];
end
v4Root=fullfile(fileparts(root),'Lora(eg)','comparison_experiments', ...
    'stage55_sf12_sf11_flow_v4_noldro');
v4Files=[dir(fullfile(v4Root,'src','**','*.m')); ...
    dir(fullfile(v4Root,'config','*.m')); ...
    dir(fullfile(v4Root,'config','*.json'))];
v4Hashes=strings(numel(v4Files),2);
for k=1:numel(v4Files)
    path=fullfile(v4Files(k).folder,v4Files(k).name);
    v4Hashes(k,:)=[string(path),string(localSha256(path))];
end
signature=dreConfigurationSignature(struct('config',config, ...
    'sourceHashes',sourceHashes,'v4Hashes',v4Hashes, ...
    'packetRange',[firstPacketId lastPacketId],'snrDb',-21));
output=fullfile(root,'results','refined_lr_independent_holdout');
if ~isfolder(output),mkdir(output);end
matPath=fullfile(output,'refined_lr_independent_holdout.mat');
if isfile(matPath)
    cached=load(matPath,'result');
    if ~strcmp(cached.result.signature,signature)
        error('DRE:HoldoutCache','Existing holdout has another signature.');
    end
    result=cached.result;
    localWriteSidecars(result.table,output);
    return
end

n=lastPacketId-firstPacketId+1;
caseCells=cell(2,1);
centroidConfig=struct('samplesPerSymbol',config.v4.samplesPerSymbol, ...
    'zeroPaddingFactor',4);
for ci=1:2
    errors=zeros(n,3,2,'uint16');
    for index=1:n
        packetId=firstPacketId+index-1;
        key=struct('planVersion','unified-v16-test','phase','paired-grid', ...
            'track','B-method-aligned','channel','AWGN', ...
            'comparisonMode','case-anchor-controlled','snrDb',-21, ...
            'replicateId',packetId,'packetId',packetId, ...
            'eventType','paired-frame','eventIndex',ci*100+10, ...
            'sampleIndex',0);
        ledger=v4EventRandomLedger(884000000,key);
        frame=v4GenerateBCaseAnchorFrame(config.v4, ...
            config.caseStartTimeSec(ci),-21,ledger);
        rows=[frame.observation.layout.bootstrapRows; ...
            frame.observation.layout.dataRows];
        estimate=dreEstimatePaperCentroids10( ...
            frame.observation.rxPhysical(rows,:),centroidConfig);
        receivers={ ...
            dreProjectPaperExact10Decode(frame.observation,config, ...
                'adaptive',estimate.rawBins), ...
            dreProjectRefinedLRDecode(frame.observation,config, ...
                16,'ordinary',estimate.rawBins), ...
            dreProjectRefinedLRDecode(frame.observation,config, ...
                8,'theil-sen',estimate.rawBins)};
        for method=1:3
            rx=receivers{method};
            if rx.usesPayloadTruth || rx.usesOrbitTruth || ...
                    rx.knownMidamblesUsed~=0
                error('DRE:HoldoutTruth','Receiver contract violated.');
            end
            errors(index,method,1)=uint16(sum( ...
                rx.detectedPhysicalBins~=frame.truth.payloadPhysicalBins));
            errors(index,method,2)=uint16(sum( ...
                rx.hardDecodedDataBits(:)~=frame.truth.dataBits(:)));
        end
        if mod(index,100)==0
            fprintf('Independent holdout case %d -21 dB: %d/%d\n',ci,index,n);
        end
    end
    caseCells{ci}=struct('caseIndex',ci,'snrDb',-21, ...
        'firstPacketId',firstPacketId,'lastPacketId',lastPacketId, ...
        'errors',errors);
end
cases=vertcat(caseCells{:});
summary=localSummary(cases);
result=struct('status','COMPLETE','signature',signature, ...
    'config',config,'sourceHashes',sourceHashes,'v4Hashes',v4Hashes, ...
    'packetRange',[firstPacketId lastPacketId], ...
    'cases',cases,'table',summary,'pairedFrames',true, ...
    'usesPayloadTruth',false);
save(matPath,'result','-v7.3');
localWriteSidecars(summary,output);
end

function t=localSummary(cases)
labels=["Paper H8";"OLS H16";"Theil-Sen H8"];
caseIndex=zeros(6,1);method=strings(6,1);
packetCount=1000*ones(6,1);symbolErrors=zeros(6,1);
symbolCount=112000*ones(6,1);bitErrors=zeros(6,1);
bitCount=768000*ones(6,1);ser=zeros(6,1);ber=zeros(6,1);
serLow95=zeros(6,1);serHigh95=zeros(6,1);
berLow95=zeros(6,1);berHigh95=zeros(6,1);
baselineMinusMethodSer=zeros(6,1);
baselineMinusMethodSerLow95=zeros(6,1);
baselineMinusMethodSerHigh95=zeros(6,1);
row=0;
for ci=1:2
    e=double(cases(ci).errors);
    stream=RandStream('mt19937ar','Seed',946500000+ci);
    bootSer=zeros(2000,3);bootBer=zeros(2000,3);
    for draw=1:2000
        sample=randi(stream,1000,1000,1);
        bootSer(draw,:)=sum(e(sample,:,1),1)/112000;
        bootBer(draw,:)=sum(e(sample,:,2),1)/768000;
    end
    boundsSer=prctile(bootSer,[2.5 97.5],1);
    boundsBer=prctile(bootBer,[2.5 97.5],1);
    for mi=1:3
        row=row+1;
        caseIndex(row)=ci;method(row)=labels(mi);
        symbolErrors(row)=sum(e(:,mi,1));
        bitErrors(row)=sum(e(:,mi,2));
        ser(row)=symbolErrors(row)/symbolCount(row);
        ber(row)=bitErrors(row)/bitCount(row);
        serLow95(row)=boundsSer(1,mi);serHigh95(row)=boundsSer(2,mi);
        berLow95(row)=boundsBer(1,mi);berHigh95(row)=boundsBer(2,mi);
        baselineMinusMethodSer(row)= ...
            (sum(e(:,1,1))-sum(e(:,mi,1)))/symbolCount(row);
        difference=bootSer(:,1)-bootSer(:,mi);
        bounds=prctile(difference,[2.5 97.5]);
        baselineMinusMethodSerLow95(row)=bounds(1);
        baselineMinusMethodSerHigh95(row)=bounds(2);
    end
end
t=table(caseIndex,method,packetCount,symbolErrors,symbolCount, ...
    bitErrors,bitCount,ser,serLow95,serHigh95,ber,berLow95,berHigh95, ...
    baselineMinusMethodSer,baselineMinusMethodSerLow95, ...
    baselineMinusMethodSerHigh95);
end

function localWriteSidecars(t,output)
writetable(t,fullfile(output,'refined_lr_independent_holdout.csv'));
figure('Visible','off','Color','w','Position',[100 100 950 450]);
for ci=1:2
    subplot(1,2,ci);
    bar(t.ser(t.caseIndex==ci));
    xticks(1:3);xticklabels({'Paper H8','OLS H16','Theil-Sen H8'});
    ylabel('SER');ylim([0 0.3]);grid on;
    title(sprintf('Case %d, -21 dB, fresh 1000 packets',ci));
end
exportgraphics(gcf,fullfile(output,'refined_lr_independent_holdout.png'), ...
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
