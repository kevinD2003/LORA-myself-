function result = run_refined_lr_paired_ber_report()
%RUN_REFINED_LR_PAIRED_BER_REPORT Add packet-paired BER gain intervals.
%   Reuses frozen per-packet errors; no receiver or waveform is rerun.

root=dreSetupPaths(false);
screen=load(fullfile(root,'results','refined_lr_v1', ...
    'refined_lr_v1.mat'),'result');
holdout=load(fullfile(root,'results','refined_lr_independent_holdout', ...
    'refined_lr_independent_holdout.mat'),'result');
screen=screen.result;holdout=holdout.result;
if ~strcmp(screen.status,'COMPLETE') || ~strcmp(holdout.status,'COMPLETE') || ...
        screen.developmentPackets~=150 || ...
        ~isequal(holdout.packetRange,[1001 2000])
    error('DRE:PairedBerSource','Complete disjoint source results required.');
end
sourcePath=fullfile(root,'scripts','run_refined_lr_paired_ber_report.m');
sourceHash=localSha256(sourcePath);
signature=dreConfigurationSignature(struct( ...
    'screenSignature',screen.signature, ...
    'holdoutSignature',holdout.signature, ...
    'reportSourceHash',sourceHash,'draws',2000));
output=fullfile(root,'results','refined_lr_paired_ber');
if ~isfolder(output),mkdir(output);end
matPath=fullfile(output,'paired_ber_report.mat');
if isfile(matPath)
    cached=load(matPath,'result');
    if ~strcmp(cached.result.signature,signature)
        error('DRE:PairedBerCache','Existing report has another signature.');
    end
    result=cached.result;
    localWriteSidecars(result,output);
    return
end

screenTable=screen.table;
holdoutTable=holdout.table;
screenTable=localAddFields(screenTable);
holdoutTable=localAddFields(holdoutTable);
names=["development","validation","all"];
for ci=1:2
    screenErrors=double(screen.cases(ci).errors);
    subsets={1:150,151:1000,1:1000};
    for si=1:3
        indices=subsets{si};n=numel(indices);
        stream=RandStream('mt19937ar','Seed',946400000+ci*10+si);
        bootBer=zeros(2000,3);
        for draw=1:2000
            sample=indices(randi(stream,n,n,1));
            bootBer(draw,:)=sum(screenErrors(sample,:,2),1)/(n*768);
        end
        rows=screenTable.caseIndex==ci & screenTable.subset==names(si);
        screenTable=localFillRows(screenTable,rows, ...
            screenErrors(indices,:,2),bootBer,n);
    end
    holdErrors=double(holdout.cases(ci).errors);
    stream=RandStream('mt19937ar','Seed',946500000+ci);
    bootBer=zeros(2000,3);
    for draw=1:2000
        sample=randi(stream,1000,1000,1);
        bootBer(draw,:)=sum(holdErrors(sample,:,2),1)/768000;
    end
    rows=holdoutTable.caseIndex==ci;
    holdoutTable=localFillRows(holdoutTable,rows, ...
        holdErrors(:,:,2),bootBer,1000);
end
result=struct('status','COMPLETE','signature',signature, ...
    'screenSignature',screen.signature, ...
    'holdoutSignature',holdout.signature, ...
    'reportSourceHash',sourceHash,'screenTable',screenTable, ...
    'holdoutTable',holdoutTable,'bootstrapDraws',2000, ...
    'resamplingUnit','paired packet');
save(matPath,'result','-v7.3');
localWriteSidecars(result,output);
end

function t=localAddFields(t)
n=height(t);
t.baselineMinusMethodBer=zeros(n,1);
t.baselineMinusMethodBerLow95=zeros(n,1);
t.baselineMinusMethodBerHigh95=zeros(n,1);
end

function t=localFillRows(t,rows,bitErrors,bootBer,n)
indices=find(rows);
if numel(indices)~=3 || size(bitErrors,2)~=3
    error('DRE:PairedBerRows','Expected three paired methods.');
end
for method=1:3
    index=indices(method);
    difference=bootBer(:,1)-bootBer(:,method);
    bounds=prctile(difference,[2.5 97.5]);
    t.baselineMinusMethodBer(index)= ...
        (sum(bitErrors(:,1))-sum(bitErrors(:,method)))/(n*768);
    t.baselineMinusMethodBerLow95(index)=bounds(1);
    t.baselineMinusMethodBerHigh95(index)=bounds(2);
end
end

function localWriteSidecars(result,output)
writetable(result.screenTable,fullfile(output,'screen_with_paired_ber.csv'));
writetable(result.holdoutTable,fullfile(output,'holdout_with_paired_ber.csv'));
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
