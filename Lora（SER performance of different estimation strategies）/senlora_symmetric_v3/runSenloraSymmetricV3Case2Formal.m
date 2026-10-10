function output = runSenloraSymmetricV3Case2Formal(options)
%RUNSENLORASYMMETRICV3CASE2FORMAL Checkpointed Case2 SNR Formal curve.

arguments
    options.StopAfterPacket (1,1) double {mustBeInteger,mustBePositive} = 1000
    options.WorkerCount (1,1) double {mustBeInteger,mustBePositive} = 6
end

paths = exp1SetupPaths();
addpath(fullfile(paths.projectRoot,'review_first_v1'));
addpath(fullfile(paths.projectRoot,'senlora_symmetric_v2'));
config = exp1Config();
plan = senloraSymmetricV3Config(config);
parameters = v4LoadMethodAlignedR3ParametersV1();
parentAudit = exp1ValidateFrozenParent(config);

snrDb = (-30:-21).';
snrCount = numel(snrDb);
formalPackets = config.formalPackets;
maximumPacket = min(formalPackets,options.StopAfterPacket);
payloadCount = config.parent.payloadSymbolCount;
checkpointEvery = config.checkpointEveryPackets;
caseIndex = 2;
caseStartSec = 0;
root = fullfile(paths.resultsRoot,'senlora_symmetric_v3','case2_formal');
if ~isfolder(root), mkdir(root); end
checkpointPath = fullfile(root,'CASE2_FORMAL_CHECKPOINT.mat');
signature = localSignature(paths,config,plan,parentAudit,snrDb, ...
    formalPackets,caseIndex,caseStartSec);

if isfile(checkpointPath)
    loaded = load(checkpointPath);
    localValidateCheckpoint(loaded,signature,snrCount,formalPackets);
    v2Errors = loaded.v2Errors;
    v3Errors = loaded.v3Errors;
    parentErrors = loaded.parentErrors;
    failed = loaded.failed;
    loboVerified = loaded.loboVerified;
    parentProtected = loaded.parentProtected;
    completed = loaded.completed;
    startedUtc = loaded.startedUtc;
    lastUpdatedUtc = loaded.lastUpdatedUtc;
else
    v2Errors = zeros(snrCount,formalPackets,'uint16');
    v3Errors = zeros(snrCount,formalPackets,'uint16');
    parentErrors = zeros(snrCount,formalPackets,'uint16');
    failed = false(snrCount,formalPackets);
    loboVerified = false(snrCount,formalPackets);
    parentProtected = false(snrCount,formalPackets);
    completed = false(snrCount,formalPackets);
    startedUtc = localUtcNow();
    lastUpdatedUtc = startedUtc;
end

if any(~completed(:,1:maximumPacket),'all')
    pool = gcp('nocreate');
    if isempty(pool)
        parpool('local',options.WorkerCount);
    elseif pool.NumWorkers~=options.WorkerCount
        error('EXP5V3:Case2FormalWorkerCount', ...
            'Existing pool has %d workers; requested %d.', ...
            pool.NumWorkers,options.WorkerCount);
    end
end

for blockStart = 1:checkpointEvery:maximumPacket
    packetIds = blockStart:min(maximumPacket, ...
        blockStart+checkpointEvery-1);
    [snrRows,packetColumns] = find(~completed(:,packetIds));
    if isempty(snrRows), continue; end
    jobSnrRows = snrRows;
    jobPackets = packetIds(packetColumns).';
    jobSnrDb = snrDb(jobSnrRows);
    jobCount = numel(jobSnrRows);
    jobV2 = zeros(jobCount,1,'uint16');
    jobV3 = zeros(jobCount,1,'uint16');
    jobParent = zeros(jobCount,1,'uint16');
    jobFailed = false(jobCount,1);
    jobLobo = false(jobCount,1);
    jobProtected = false(jobCount,1);
    parfor job = 1:jobCount
        packetId = jobPackets(job);
        packet = localEvaluatePacket(packetId,jobSnrDb(job), ...
            caseIndex,caseStartSec,config,plan,parameters,payloadCount);
        jobV2(job) = packet.v2Errors;
        jobV3(job) = packet.v3Errors;
        jobParent(job) = packet.parentErrors;
        jobFailed(job) = packet.failed;
        jobLobo(job) = packet.loboVerified;
        jobProtected(job) = packet.parentProtected;
    end
    for job = 1:jobCount
        snrIndex = jobSnrRows(job);
        packetId = jobPackets(job);
        v2Errors(snrIndex,packetId) = jobV2(job);
        v3Errors(snrIndex,packetId) = jobV3(job);
        parentErrors(snrIndex,packetId) = jobParent(job);
        failed(snrIndex,packetId) = jobFailed(job);
        loboVerified(snrIndex,packetId) = jobLobo(job);
        parentProtected(snrIndex,packetId) = jobProtected(job);
        completed(snrIndex,packetId) = true;
    end
    lastUpdatedUtc = localUtcNow();
    localSaveCheckpoint(checkpointPath,signature,v2Errors,v3Errors, ...
        parentErrors,failed,loboVerified,parentProtected,completed, ...
        startedUtc,lastUpdatedUtc);
    fprintf(['EXP5V3 Case2 Formal packets=%d/%d cellsComplete=%d/%d ' ...
        'failures=%d updated=%s\n'],max(packetIds),formalPackets, ...
        sum(completed(:,1:max(packetIds)),'all'), ...
        snrCount*max(packetIds),sum(failed,'all'),lastUpdatedUtc);
end

formalComplete = all(completed,'all');
if ~formalComplete
    output = struct('status','CASE2_FORMAL_IN_PROGRESS', ...
        'completedPackets',sum(completed,'all'), ...
        'totalPackets',numel(completed), ...
        'checkpointPath',checkpointPath, ...
        'lastUpdatedUtc',lastUpdatedUtc,'formalStarted',true, ...
        'formalComplete',false);
    return
end

[summary,shape] = localSummarize(snrDb,v2Errors,v3Errors,parentErrors, ...
    failed,loboVerified,parentProtected,payloadCount,plan);
csvPath = fullfile(root,'CASE2_FORMAL_SUMMARY.csv');
matPath = fullfile(root,'CASE2_FORMAL_RESULT.mat');
figurePath = fullfile(root,'CASE2_V3_FORMAL_SER.png');
comparisonPath = fullfile(root,'CASE2_V3_VS_UNIFIED_V23.png');
reportPath = fullfile(root,'CASE2_FORMAL_REPORT.md');
writetable(summary,csvPath);
save(matPath,'summary','shape','signature','plan','v2Errors', ...
    'v3Errors','parentErrors','failed','loboVerified', ...
    'parentProtected','completed','startedUtc','lastUpdatedUtc','-v7.3');
localPlot(summary,figurePath,comparisonPath,paths,signature);
localMarkdown(reportPath,summary,shape);
output = struct('status',shape.status,'summary',summary,'shape',shape, ...
    'csvPath',csvPath,'matPath',matPath,'figurePath',figurePath, ...
    'comparisonPath',comparisonPath,'reportPath',reportPath, ...
    'checkpointPath',checkpointPath,'lastUpdatedUtc',lastUpdatedUtc, ...
    'formalStarted',true, ...
    'formalComplete',true);
end

function packet = localEvaluatePacket(packetId,snrDb,caseIndex,caseStartSec, ...
        config,plan,parameters,payloadCount)
packet = struct('v2Errors',uint16(payloadCount), ...
    'v3Errors',uint16(payloadCount),'parentErrors',uint16(payloadCount), ...
    'failed',true,'loboVerified',false,'parentProtected',false);
try
    ledger = senloraSymmetricV3SeedPlan(config,plan,'formal', ...
        caseIndex,snrDb,packetId);
    frame = exp1GenerateFrame(config,caseStartSec,snrDb,ledger);
    common = v4CommonBootstrap( ...
        frame.observation.rxPhysical(1:8,:),config.parent, ...
        SearchStepBins=parameters.searchStepBins);
    result = senloraSymmetricV3Decode(frame.observation,common,config,plan);
    truth = frame.truth.payloadPhysicalBins(:);
    packet.v2Errors = uint16(sum( ...
        result.v2CandidateDetectedPhysicalBins(:)~=truth));
    packet.v3Errors = uint16(sum(result.detectedPhysicalBins(:)~=truth));
    packet.parentErrors = uint16(sum( ...
        result.frozenParentHypothesis.detectedPhysicalBins(:)~=truth));
    packet.failed = false;
    packet.loboVerified = result.decision.leaveOneBlockOut && ...
        ~result.decision.selfBlockUsedForFit;
    packet.parentProtected = result.decision.parentStaticProtected;
catch exception
    warning('EXP5V3:Case2FormalPacketFailure', ...
        'SNR %.1f packet %d failed: %s',snrDb,packetId,exception.message);
end
end

function signature = localSignature(paths,config,plan,parentAudit,snrDb, ...
        formalPackets,caseIndex,caseStartSec)
entry = which('runSenloraSymmetricV3Case2Formal');
required = matlab.codetools.requiredFilesAndProducts(entry);
explicitNames = {'runSenloraSymmetricV3Case2Formal', ...
    'senloraSymmetricV3Config','senloraSymmetricV3Decode', ...
    'senloraSymmetricV3SeedPlan','senloraSymmetricV2Decode', ...
    'exp1Config','exp1GenerateFrame','v4CommonBootstrap', ...
    'exp1Stage55Decode','reviewStaticHypothesis'};
explicitPaths = strings(numel(explicitNames),1);
for index = 1:numel(explicitNames)
    explicitPaths(index) = string(which(explicitNames{index}));
    if strlength(explicitPaths(index))==0
        error('EXP5V3:Case2FormalDependencyMissing', ...
            'Cannot resolve dependency %s.',explicitNames{index});
    end
end
sourcePaths = unique([string(required(:));explicitPaths]);
inScope = startsWith(sourcePaths,string(paths.projectRoot)+filesep, ...
    'IgnoreCase',true) | ...
    startsWith(sourcePaths,string(config.parentRoot)+filesep, ...
    'IgnoreCase',true);
sourcePaths = sort(sourcePaths(inScope));
sourceHashes = strings(size(sourcePaths));
for index = 1:numel(sourcePaths)
    sourceHashes(index) = exp1Sha256(sourcePaths(index));
end
v4SummaryPath = fullfile(paths.parentRoot,'results','method_aligned', ...
    'unified_v23_report','summary.csv');
v4Summary = readtable(v4SummaryPath,'TextType','string');
v4Stage = sortrows(v4Summary( ...
    v4Summary.caseIndex==2 & v4Summary.method=="Stage55",:),'snrDb');
if height(v4Stage)~=numel(snrDb) || ...
        ~isequal(v4Stage.snrDb,snrDb) || ...
        ~all(v4Stage.packets==formalPackets) || ...
        ~all(v4Stage.symbolCount==formalPackets*config.parent.payloadSymbolCount)
    error('EXP5V3:Case2FormalV4Coverage', ...
        'V4 comparison summary does not cover the frozen Case2 grid.');
end
signature = struct('identity',plan.identity, ...
    'receiverVersion',plan.receiverVersion, ...
    'formalRootSeed',plan.formalRootSeed, ...
    'formalPackets',formalPackets,'snrDb',snrDb, ...
    'caseIndex',caseIndex,'caseStartSec',caseStartSec, ...
    'payloadSymbolCount',config.parent.payloadSymbolCount, ...
    'parentManifestSha256',parentAudit.manifestSha256, ...
    'v4SummaryPath',string(v4SummaryPath), ...
    'v4SummarySha256',exp1Sha256(v4SummaryPath), ...
    'v4SummaryCase2Rows',height(v4Stage), ...
    'v4SummaryPacketsPerCell',formalPackets, ...
    'v4SummarySymbolCountPerCell', ...
        formalPackets*config.parent.payloadSymbolCount, ...
    'implementationSourcePaths',sourcePaths, ...
    'implementationSourceSha256',sourceHashes);
end

function localValidateCheckpoint(loaded,signature,snrCount,formalPackets)
required = {'signature','v2Errors','v3Errors','parentErrors','failed', ...
    'loboVerified','parentProtected','completed','startedUtc', ...
    'lastUpdatedUtc','stateDigest'};
for index = 1:numel(required)
    if ~isfield(loaded,required{index})
        error('EXP5V3:Case2FormalCheckpointField', ...
            'Checkpoint is missing %s.',required{index});
    end
end
if ~isequaln(loaded.signature,signature)
    error('EXP5V3:Case2FormalCheckpointSignature', ...
        'Checkpoint signature does not match frozen inputs.');
end
expected = [snrCount,formalPackets];
if ~isequal(size(loaded.v2Errors),expected) || ...
        ~isequal(size(loaded.v3Errors),expected) || ...
        ~isequal(size(loaded.parentErrors),expected) || ...
        ~isequal(size(loaded.failed),expected) || ...
        ~isequal(size(loaded.loboVerified),expected) || ...
        ~isequal(size(loaded.parentProtected),expected) || ...
        ~isequal(size(loaded.completed),expected)
    error('EXP5V3:Case2FormalCheckpointSize', ...
        'Checkpoint array dimensions are invalid.');
end
success = loaded.completed & ~loaded.failed;
if any(loaded.failed & ~loaded.completed,'all') || ...
        ~all(loaded.loboVerified(success),'all') || ...
        any(loaded.v2Errors(~loaded.completed)~=0,'all') || ...
        any(loaded.v3Errors(~loaded.completed)~=0,'all') || ...
        any(loaded.parentErrors(~loaded.completed)~=0,'all') || ...
        any(loaded.loboVerified(~loaded.completed),'all') || ...
        any(loaded.parentProtected(~loaded.completed),'all')
    error('EXP5V3:Case2FormalCheckpointConsistency', ...
        'Checkpoint state is inconsistent with its completion mask.');
end
actualDigest = localStateDigest(loaded.signature,loaded.v2Errors, ...
    loaded.v3Errors,loaded.parentErrors,loaded.failed, ...
    loaded.loboVerified,loaded.parentProtected,loaded.completed, ...
    loaded.startedUtc,loaded.lastUpdatedUtc);
if ~strcmpi(loaded.stateDigest,actualDigest)
    error('EXP5V3:Case2FormalCheckpointDigest', ...
        'Checkpoint state digest does not match its contents.');
end
end

function localSaveCheckpoint(path,signature,v2Errors,v3Errors, ...
        parentErrors,failed,loboVerified,parentProtected,completed, ...
        startedUtc,lastUpdatedUtc)
temporaryPath = [path '.tmp.' char(java.util.UUID.randomUUID) '.mat'];
stateDigest = localStateDigest(signature,v2Errors,v3Errors,parentErrors, ...
    failed,loboVerified,parentProtected,completed,startedUtc,lastUpdatedUtc);
save(temporaryPath,'signature','v2Errors','v3Errors','parentErrors', ...
    'failed','loboVerified','parentProtected','completed','startedUtc', ...
    'lastUpdatedUtc','stateDigest','-v7.3');
probe = load(temporaryPath);
probeDigest = localStateDigest(probe.signature,probe.v2Errors, ...
    probe.v3Errors,probe.parentErrors,probe.failed,probe.loboVerified, ...
    probe.parentProtected,probe.completed,probe.startedUtc, ...
    probe.lastUpdatedUtc);
if ~strcmpi(probe.stateDigest,probeDigest)
    error('EXP5V3:Case2FormalCheckpointTemporaryDigest', ...
        'Temporary checkpoint failed its state-digest verification.');
end
[moved,message] = movefile(temporaryPath,path,'f');
if ~moved
    error('EXP5V3:Case2FormalCheckpointMove', ...
        'Cannot replace checkpoint: %s',message);
end
end

function hash = localStateDigest(signature,v2Errors,v3Errors,parentErrors, ...
        failed,loboVerified,parentProtected,completed,startedUtc,lastUpdatedUtc)
digest = java.security.MessageDigest.getInstance('SHA-256');
localDigestText(digest,'signature',jsonencode(signature));
localDigestArray(digest,'v2Errors',v2Errors);
localDigestArray(digest,'v3Errors',v3Errors);
localDigestArray(digest,'parentErrors',parentErrors);
localDigestArray(digest,'failed',failed);
localDigestArray(digest,'loboVerified',loboVerified);
localDigestArray(digest,'parentProtected',parentProtected);
localDigestArray(digest,'completed',completed);
localDigestText(digest,'startedUtc',startedUtc);
localDigestText(digest,'lastUpdatedUtc',lastUpdatedUtc);
hashBytes = typecast(digest.digest(),'uint8');
hash = lower(reshape(dec2hex(hashBytes,2).',1,[]));
end

function localDigestArray(digest,name,value)
localDigestText(digest,[name ':class'],class(value));
dimensions = typecast(uint64(size(value)),'uint8');
digest.update(typecast(dimensions(:),'int8'));
if islogical(value)
    bytes = uint8(value(:));
else
    bytes = typecast(value(:),'uint8');
end
if ~isempty(bytes)
    digest.update(typecast(bytes(:),'int8'));
end
end

function localDigestText(digest,name,value)
bytes = unicode2native([name '=' char(value)],'UTF-8');
if ~isempty(bytes)
    digest.update(typecast(uint8(bytes(:)),'int8'));
end
end

function [summary,shape] = localSummarize(snrDb,v2Errors,v3Errors, ...
        parentErrors,failed,loboVerified,parentProtected,payloadCount,plan)
packets = size(v3Errors,2);
symbolCount = packets*payloadCount;
rows = cell(numel(snrDb),17);
for snrIndex = 1:numel(snrDb)
    v2 = sum(double(v2Errors(snrIndex,:)));
    v3 = sum(double(v3Errors(snrIndex,:)));
    parent = sum(double(parentErrors(snrIndex,:)));
    [lower,upper] = localWilson(v3,symbolCount);
    rows(snrIndex,:) = {snrDb(snrIndex),packets,v3,symbolCount, ...
        v3/symbolCount,lower,upper,v2,v2/symbolCount,parent, ...
        parent/symbolCount,v3-v2,(v3-v2)/symbolCount, ...
        sum(parentProtected(snrIndex,:)),sum(failed(snrIndex,:)), ...
        all(loboVerified(snrIndex,:)),v3<=v2};
end
summary = cell2table(rows,'VariableNames',{'snrDb','packets', ...
    'v3SymbolErrors','symbolCount','v3Ser','v3WilsonLower95', ...
    'v3WilsonUpper95','v2SymbolErrors','v2Ser','parentSymbolErrors', ...
    'parentSer','v3MinusV2Errors','v3MinusV2Ser', ...
    'parentProtectedPackets','failedPackets','leaveOneBlockOutVerified', ...
    'v3NoWorseThanV2'});
last = height(summary);
hardPass = sum(failed,'all')==0 && all(loboVerified,'all') && ...
    summary.v3Ser(last)<=plan.targetCenterSer && ...
    summary.v3Ser(last)<=summary.parentSer(last);
if hardPass
    status = 'CASE2_FORMAL_PASS';
else
    status = 'CASE2_FORMAL_FAIL';
end
shape = struct('status',status,'formalComplete',true, ...
    'failedPackets',sum(failed,'all'), ...
    'leaveOneBlockOutVerified',all(loboVerified,'all'), ...
    'allSnrNoWorseThanV2',all(summary.v3NoWorseThanV2), ...
    'minus21V3Ser',summary.v3Ser(last), ...
    'minus21ParentSer',summary.parentSer(last), ...
    'minus21TargetSer',plan.targetCenterSer, ...
    'minus21NotWorseParent',summary.v3Ser(last)<=summary.parentSer(last), ...
    'minus21BelowTarget',summary.v3Ser(last)<=plan.targetCenterSer);
end

function [lower,upper] = localWilson(errorCount,total)
z = 1.95996398454005;
p = errorCount/total;
denominator = 1+z^2/total;
center = (p+z^2/(2*total))/denominator;
radius = z*sqrt(p*(1-p)/total+z^2/(4*total^2))/denominator;
lower = max(0,center-radius);
upper = min(1,center+radius);
end

function localPlot(summary,figurePath,comparisonPath,paths,signature)
floorValue = 0.5/summary.symbolCount(1);
f = figure('Visible','off','Color','w','Position',[100 100 1050 650]);
semilogy(summary.snrDb,max(summary.v3Ser,floorValue),'-o', ...
    'Color',[0.10 0.50 0.20],'MarkerFaceColor','w','LineWidth',1.9, ...
    'DisplayName','SenLoRa V3');
hold on
semilogy(summary.snrDb,max(summary.v2Ser,floorValue),'--s', ...
    'Color',[0 0.35 0.70],'LineWidth',1.5,'DisplayName','V2 candidate');
semilogy(summary.snrDb,max(summary.parentSer,floorValue),'-.^', ...
    'Color',[0.50 0.50 0.50],'LineWidth',1.4,'DisplayName','Frozen parent');
grid on;grid minor;xlabel('SNR (dB)');ylabel('SER');
title('SenLoRa V3 Case2 Formal SER');legend('Location','southwest');
xlim([-30 -21]);ylim([1e-5 1.1]);exportgraphics(f,figurePath,'Resolution',220);
close(f);

oldPath = fullfile(paths.parentRoot,'results','method_aligned', ...
    'unified_v23_report','summary.csv');
if ~strcmpi(exp1Sha256(oldPath),signature.v4SummarySha256)
    error('EXP5V3:Case2FormalV4SummaryDrift', ...
        'V4 comparison summary changed after Formal started.');
end
old = readtable(oldPath,'TextType','string');
stageRows = sortrows(old(old.caseIndex==2 & old.method=="Stage55",:),'snrDb');
if height(stageRows)~=signature.v4SummaryCase2Rows || ...
        ~isequal(stageRows.snrDb,summary.snrDb) || ...
        ~all(stageRows.packets==signature.v4SummaryPacketsPerCell) || ...
        ~all(stageRows.symbolCount==signature.v4SummarySymbolCountPerCell)
    error('EXP5V3:Case2FormalV4SummaryCoverage', ...
        'V4 comparison rows do not match the frozen coverage contract.');
end
f = figure('Visible','off','Color','w','Position',[100 100 1050 650]);
semilogy(stageRows.snrDb,stageRows.ser,'-s','Color',[0 0.35 0.70], ...
    'LineWidth',1.7,'DisplayName','V4 unified-v23 Stage55');
hold on
semilogy(summary.snrDb,max(summary.v3Ser,floorValue),'-o', ...
    'Color',[0.10 0.50 0.20],'MarkerFaceColor','w','LineWidth',1.9, ...
    'DisplayName','Current SenLoRa V3');
grid on;grid minor;xlabel('SNR (dB)');ylabel('SER');
title('Case2 SER: current V3 vs V4 unified-v23');
legend('Location','southwest');xlim([-30 -21]);ylim([1e-5 1.1]);
exportgraphics(f,comparisonPath,'Resolution',220);close(f);
end

function localMarkdown(path,summary,shape)
[fid,message] = fopen(path,'w','n','UTF-8');
if fid<0
    error('EXP5V3:Case2FormalReportOpen', ...
        'Cannot open report: %s',message);
end
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'# SenLoRa V3 Case2 Formal\n\n');
fprintf(fid,'Status: **%s**  \nFormal complete: **YES**\n\n',shape.status);
fprintf(fid,'- Failed packets: %d\n',shape.failedPackets);
fprintf(fid,'- LOBO verified: %d\n',shape.leaveOneBlockOutVerified);
fprintf(fid,'- All SNR points no worse than V2: %d\n', ...
    shape.allSnrNoWorseThanV2);
fprintf(fid,'- -21 dB V3/parent/target SER: %.9g / %.9g / %.9g\n', ...
    shape.minus21V3Ser,shape.minus21ParentSer,shape.minus21TargetSer);
fprintf(fid,'- -21 dB no worse than parent: %d\n', ...
    shape.minus21NotWorseParent);
fprintf(fid,'- -21 dB below target: %d\n\n',shape.minus21BelowTarget);
fprintf(fid,'| SNR | V3 errors | V3 SER | Wilson 95%% | V2 SER | Parent SER |\n');
fprintf(fid,'|---:|---:|---:|:---|---:|---:|\n');
for row = 1:height(summary)
    fprintf(fid,'| %.0f | %d | %.9g | [%.9g, %.9g] | %.9g | %.9g |\n', ...
        summary.snrDb(row),summary.v3SymbolErrors(row), ...
        summary.v3Ser(row),summary.v3WilsonLower95(row), ...
        summary.v3WilsonUpper95(row),summary.v2Ser(row), ...
        summary.parentSer(row));
end
clear cleanup
end

function text = localUtcNow()
text = char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd''T''HH:mm:ss''Z'''));
end
