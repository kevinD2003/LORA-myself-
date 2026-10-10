function output = runSenloraSymmetricV8RicianPrecComparison(options)
%RUNSENLORASYMMETRICV8RICIANPRECCOMPARISON Existing PREC V9 on native K10 frames.
arguments
    options.WorkerCount (1,1) double {mustBeInteger,mustBePositive} = 4
    options.StopAfterPacket (1,1) double {mustBeInteger,mustBePositive} = 1000
end
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here,'..','scripts'));
paths = exp1SetupPaths();
addpath(here);
config = exp1Config();
c = config.parent;
plan = senloraSymmetricV8Config(config);
[raw,summary,inputPaths] = localLoadInputs(config,here);
signature = localSignature(config,inputPaths);
root = fullfile(paths.resultsRoot,'senlora_symmetric_v8', ...
    'case_snr_rician_k10_prec_comparison');
if ~isfolder(root), mkdir(root); end
checkpointPath = fullfile(root,'RICIAN_PREC_CHECKPOINT.mat');
n = height(raw);
if isfile(checkpointPath)
    state = load(checkpointPath);
    if ~isequaln(state.signature,signature) || ...
            ~isequal(size(state.completed),[n,1]) || ...
            ~strcmp(state.stateDigest,localDigest(state))
        error('EXP5V8:PrecCheckpoint','Incompatible PREC checkpoint.');
    end
else
    state = struct('signature',signature,'completed',false(n,1), ...
        'precErrors',nan(n,1),'precCfoRmseBins',nan(n,1), ...
        'precStatic',false(n,1),'failed',false(n,1), ...
        'failureMessage',strings(n,1),'usesForbiddenInput',false(n,1));
    state.stateDigest = localDigest(state);
end
pending = find(~state.completed & raw.packetId<=min(options.StopAfterPacket,1000));
if ~isempty(pending)
    pool = gcp('nocreate');
    if isempty(pool)
        parpool('local',options.WorkerCount);
    elseif pool.NumWorkers~=options.WorkerCount
        error('EXP5V8:PrecWorkers','Existing worker count differs.');
    end
end
for first = 1:100:numel(pending)
    jobs = pending(first:min(first+99,numel(pending)));
    rows = raw(jobs,:);
    packets = cell(numel(jobs),1);
    parfor job = 1:numel(jobs)
        packets{job} = localEvaluate(rows(job,:),config,plan);
    end
    for job = 1:numel(jobs)
        index = jobs(job);
        p = packets{job};
        state.precErrors(index) = p.errors;
        state.precCfoRmseBins(index) = p.cfoRmseBins;
        state.precStatic(index) = p.staticSelected;
        state.failed(index) = p.failed;
        state.failureMessage(index) = p.failureMessage;
        state.usesForbiddenInput(index) = p.usesForbiddenInput;
        state.completed(index) = true;
    end
    state.stateDigest = localDigest(state);
    temporary = checkpointPath+".tmp.mat";
    save(temporary,'-struct','state','-v7.3');
    probe = load(temporary);
    if ~strcmp(probe.stateDigest,localDigest(probe))
        error('EXP5V8:PrecCheckpoint','Written digest mismatch.');
    end
    [ok,message] = movefile(temporary,checkpointPath,'f');
    if ~ok, error('EXP5V8:PrecCheckpoint','%s',message); end
    fprintf('Rician PREC V9: %d/20000 frames; errors=%d; failures=%d; forbidden=%d\n', ...
        sum(state.completed),sum(state.precErrors,'omitnan'), ...
        sum(state.failed),sum(state.usesForbiddenInput));
end
output = struct('status','RICIAN_PREC_IN_PROGRESS','completedFrames', ...
    sum(state.completed),'totalFrames',n,'root',root);
if ~all(state.completed), return; end
[raw,summary] = localTables(state,raw,summary,c);
writetable(raw,fullfile(root,'RICIAN_PREC_RAW_PACKETS.csv'));
writetable(summary,fullfile(root,'RICIAN_PREC_SUMMARY.csv'));
save(fullfile(root,'RICIAN_PREC_RESULT.mat'),'-struct','state','-v7.3');
localPlot(summary,root);
output.status = 'RICIAN_PREC_COMPLETE';
output.failedFrames = sum(state.failed);
output.allForbiddenFlagsFalse = ~any(state.usesForbiddenInput);
output.summary = summary;
if output.failedFrames~=0 || ~output.allForbiddenFlagsFalse
    output.status = 'RICIAN_PREC_COMPLETE_WITH_VALIDATION_FAILURE';
end
end

function p = localEvaluate(row,config,plan)
c = config.parent;
key = struct('planVersion',plan.identity,'phase','case-ser-rician-k10', ...
    'track','two-case-native','channel','Rician-K10-packet-flat', ...
    'comparisonMode','frozen-v8-vs-ideal','snrDb',row.snrDb, ...
    'replicateId',row.packetId,'packetId',row.packetId, ...
    'eventType','single-native-frame','eventIndex',row.caseIndex,'sampleIndex',0);
seeds = v4EventRandomLedger(row.rootSeed,key);
if ~isequal([seeds.payloadSeed,seeds.noiseSeed,seeds.channelSeed], ...
        [row.payloadSeed,row.noiseSeed,row.channelSeed])
    error('EXP5V8:PrecSeeds','Native replay ledger differs.');
end
frame = senloraSymmetricV8GenerateRicianFrame( ...
    config,row.orbitStartSec,row.snrDb,seeds);
if frame.observation.layout.physicalSymbolCount~=120 || ...
        ~isempty(frame.observation.layout.midambleRows) || ...
        abs(frame.truth.channelPower-row.channelPower)>1e-12
    error('EXP5V8:PrecFrame','Native replay frame/channel differs.');
end
p = struct('errors',c.payloadSymbolCount,'cfoRmseBins',NaN, ...
    'staticSelected',false,'failed',false,'failureMessage',"", ...
    'usesForbiddenInput',false);
try
    % Same existing AWGN entry; no frame, ledger, orbit time or truth passed.
    receiver = v4HuangPrecUnifiedDecodeV9(frame.observation,c);
    detected = receiver.detectedPhysicalBins(:);
    if numel(detected)~=c.payloadSymbolCount || ...
            any(~isfinite(detected) | detected<0 | detected>=c.dataAlphabetSize | ...
            detected~=floor(detected))
        error('EXP5V8:PrecOutput','Invalid detected-symbol output.');
    end
    cfo = receiver.estimatedCfoBins(:);
    if numel(cfo)~=c.payloadSymbolCount || any(~isfinite(cfo)) || ...
            any(abs(cfo-cfo(1))>1e-12) || ...
            any(receiver.virtualPilotAccepted) || any(receiver.explicitMidambleAccepted)
        error('EXP5V8:PrecOutput','Existing fixed-CFO/no-pilot contract changed.');
    end
    p.errors = sum(detected~=frame.truth.payloadPhysicalBins(:));
    p.cfoRmseBins = sqrt(mean((cfo-frame.truth.dataCfoBins(:)).^2));
    p.staticSelected = receiver.modeEvidence.staticSelected;
    names = {'usesPayloadTruth','usesOrbitTruth','usesCaseIdentity', ...
        'usesSnrInput','usesTargetSer','usesPayloadFeedback','usesDopplerRate'};
    for k = 1:numel(names)
        p.usesForbiddenInput = p.usesForbiddenInput || ...
            (isfield(receiver,names{k}) && receiver.(names{k}));
    end
    p.usesForbiddenInput = p.usesForbiddenInput || receiver.modeEvidence.usesTruth;
catch exception
    p.errors = c.payloadSymbolCount;
    p.failed = true;
    p.failureMessage = string(exception.identifier)+": "+exception.message;
end
end

function [raw,summary,inputPaths] = localLoadInputs(config,here)
base = fullfile(config.projectRoot,'results','senlora_symmetric_v8');
nativeRoot = fullfile(base,'case_snr_rician_k10');
paperRoot = fullfile(base,'case_snr_rician_k10_paper_comparison');
nativeMat = fullfile(nativeRoot,'RICIAN_CASE_SNR_RESULT.mat');
nativeRaw = fullfile(nativeRoot,'RICIAN_CASE_SNR_RAW_PACKETS.csv');
nativeSummary = fullfile(nativeRoot,'RICIAN_CASE_SNR_SUMMARY.csv');
paperMat = fullfile(paperRoot,'RICIAN_PAPER_RESULT.mat');
paperRaw = fullfile(paperRoot,'RICIAN_PAPER_RAW_PACKETS.csv');
paperSummary = fullfile(paperRoot,'RICIAN_PAPER_SUMMARY.csv');
native = load(nativeMat);
bytes = getByteStreamFromArray({native.signature,native.senloraErrors, ...
    native.idealErrors,native.firstErrors,native.acceptedBlocks,native.rateGain, ...
    native.channelPower,native.failed,native.failureMessage,native.usesForbiddenInput, ...
    native.payloadSeed,native.noiseSeed,native.channelSeed,native.completed});
if ~strcmp(native.stateDigest,localBytesHash(bytes)) || ...
        ~isequal(size(native.completed),[2,10,1000]) || ...
        ~all(native.completed,'all') || any(native.failed,'all') || ...
        any(native.usesForbiddenInput,'all')
    error('EXP5V8:PrecBaseline','Native result invalid/incomplete.');
end
sig = native.signature;
if sig.seedRoot~=1032900000 || sig.packetsPerCell~=1000 || ...
        ~isequal(sig.caseStartSec,[-366;0]) || ~isequal(sig.snrDb,(-30:-21).') || ...
        sig.ricianKDb~=10 || ~strcmp(sig.ricianCoherence,'packet-flat')
    error('EXP5V8:PrecBaseline','Native conditions differ.');
end
localCheckHashes(sig.executionSourcePaths,sig.executionSourceSha256);
localCheckHashes(sig.parameterSourcePaths,sig.parameterSourceSha256);
localCheckHashes(sig.frozenManifestPath,sig.frozenManifestSha256);
localCheckHashes(sig.paperPath,sig.paperSha256);
raw = readtable(nativeRaw);
summary = readtable(nativeSummary);
senloraSymmetricV8ValidateRicianReferenceSummary(summary,config.parent);
keys = raw{:,{'caseIndex','snrDb','packetId'}};
if height(raw)~=20000 || any(~isfinite(keys),'all') || ...
        size(unique(keys,'rows'),1)~=20000 || ...
        any(~ismember(raw.caseIndex,[1;2])) || any(~ismember(raw.snrDb,(-30:-21).')) || ...
        any(~ismember(raw.packetId,(1:1000).')) || ...
        any(raw.rootSeed~=sig.seedRoot | raw.payloadSymbols~=112) || ...
        any(raw.orbitStartSec~=sig.caseStartSec(raw.caseIndex)) || ...
        any(raw.senloraFailed | raw.idealFailed | raw.usesForbiddenInput)
    error('EXP5V8:PrecBaseline','Native CSV identity invalid.');
end
index = sub2ind(size(native.completed),raw.caseIndex,raw.snrDb+31,raw.packetId);
pairs = {'senloraRawErrors','senloraErrors';'idealRawErrors','idealErrors'; ...
    'payloadSeed','payloadSeed';'noiseSeed','noiseSeed';'channelSeed','channelSeed'; ...
    'channelPower','channelPower'};
for k = 1:size(pairs,1)
    v = native.(pairs{k,2});
    if any(~isfinite(raw.(pairs{k,1}))) || any(abs(raw.(pairs{k,1})-v(index))>1e-12)
        error('EXP5V8:PrecBaseline','Native CSV/MAT values differ.');
    end
end
paper = load(paperMat);
if ~strcmp(paper.stateDigest,localDigest(paper)) || ...
        ~isequal(size(paper.completed),[20000,1]) || ~all(paper.completed) || ...
        any(paper.failed,'all') || any(paper.usesForbiddenInput)
    error('EXP5V8:PrecBaseline','Paper result invalid/incomplete.');
end
localCheckHashes(paper.signature.sourcePaths,paper.signature.sourceSha256);
localCheckHashes(paper.signature.inputPaths,paper.signature.inputSha256);
pr = readtable(paperRaw);
ps = readtable(paperSummary);
senloraSymmetricV8ValidateRicianReferenceSummary(ps,config.parent);
if ~isequal(pr{:,{'caseIndex','snrDb','packetId'}},keys) || ...
        any(pr.paperRawErrors~=paper.paperErrors) || ...
        any(pr.paperFrameIdealRawErrors~=paper.paperIdealErrors) || ...
        any(pr.paperFailed | pr.paperFrameIdealFailed | pr.paperUsesForbiddenInput)
    error('EXP5V8:PrecBaseline','Paper CSV/MAT values differ.');
end
raw.paperRawErrors = pr.paperRawErrors;
raw.paperFrameIdealRawErrors = pr.paperFrameIdealRawErrors;
paperFields = {'paperRawErrors','paperFrameIdealRawErrors','paperSer','paperFrameIdealSer'};
for k = 1:numel(paperFields), summary.(paperFields{k}) = zeros(height(summary),1); end
for k = 1:height(summary)
    m = raw.caseIndex==summary.caseIndex(k) & raw.snrDb==summary.snrDb(k);
    pp = ps(ps.caseIndex==summary.caseIndex(k) & ps.snrDb==summary.snrDb(k),:);
    sums = [sum(raw.senloraRawErrors(m)),sum(raw.idealRawErrors(m)), ...
        sum(raw.paperRawErrors(m)),sum(raw.paperFrameIdealRawErrors(m))];
    ser = [summary.senloraSer(k),summary.idealSer(k),pp.paperSer,pp.paperFrameIdealSer];
    if sum(m)~=1000 || height(pp)~=1 || summary.packets(k)~=1000 || ...
            pp.packets~=1000 || any(~isfinite(ser)) || ...
            any(abs(ser-sums/112000)>1e-12) || ...
            ~isequal(sums,[summary.senloraRawErrors(k),summary.idealRawErrors(k), ...
            pp.paperRawErrors,pp.paperFrameIdealRawErrors])
        error('EXP5V8:PrecBaseline','Summary counts/SER differ.');
    end
    summary.paperRawErrors(k) = pp.paperRawErrors;
    summary.paperFrameIdealRawErrors(k) = pp.paperFrameIdealRawErrors;
    summary.paperSer(k) = pp.paperSer;
    summary.paperFrameIdealSer(k) = pp.paperFrameIdealSer;
end
% Check the exact existing AWGN receiver bodies, not only their entry names.
manifest = jsondecode(fileread(config.parentManifestPath));
names = {'v4HuangPrecUnifiedDecodeV9','v4HuangPrecDecodeV3','v4HuangStaticDecode'};
for k = 1:numel(names)
    path = which(names{k});
    relative = strrep(erase(path,[config.parentRoot,filesep]),'\','/');
    entry = manifest.files(strcmp({manifest.files.path},relative));
    if numel(entry)~=1
        error('EXP5V8:PrecBaseline','Existing PREC source not in frozen manifest.');
    end
    localCheckHashes(string(path),string(entry.sha256));
end
parameters = v4LoadMethodAlignedR3ParametersV1();
inputPaths = [string(nativeMat);string(nativeRaw);string(nativeSummary); ...
    string(paperMat);string(paperRaw);string(paperSummary); ...
    string(config.parentManifestPath);string(parameters.sourcePath); ...
    string(fullfile(fileparts(which('v4LoadMethodAlignedParametersV1')), ...
    'method_aligned_selected_parameters_v1.json')); ...
    string(fullfile(here,'v8_frozen_receiver_manifest.json'))];
end

function localCheckHashes(paths,hashes)
paths = string(paths);
hashes = string(hashes);
if numel(paths)~=numel(hashes)
    error('EXP5V8:PrecHash','Source/hash counts differ.');
end
for k = 1:numel(paths)
    if ~isfile(paths(k)) || ~strcmpi(exp1Sha256(paths(k)),hashes(k))
        error('EXP5V8:PrecHash','Input/source changed: %s.',paths(k));
    end
end
end

function signature = localSignature(config,inputPaths)
names = {'runSenloraSymmetricV8RicianPrecComparison', ...
    'senloraSymmetricV8GenerateRicianFrame','v4HuangPrecUnifiedDecodeV9', ...
    'v4HuangPrecDecodeV3','v4HuangStaticDecode'};
explicit = strings(numel(names),1);
for k = 1:numel(names), explicit(k) = string(which(names{k})); end
required = string(matlab.codetools.requiredFilesAndProducts(explicit(1)));
allPaths = unique([required(:);explicit]);
inScope = startsWith(allPaths,string(config.projectRoot)+filesep,'IgnoreCase',true) | ...
    startsWith(allPaths,string(config.parentRoot)+filesep,'IgnoreCase',true);
sourcePaths = sort(allPaths(inScope));
sourceHashes = strings(size(sourcePaths));
for k = 1:numel(sourcePaths), sourceHashes(k) = exp1Sha256(sourcePaths(k)); end
inputHashes = strings(size(inputPaths));
for k = 1:numel(inputPaths), inputHashes(k) = exp1Sha256(inputPaths(k)); end
signature = struct('identity','V8-RICIAN-K10-EXISTING-PREC-V9-V1', ...
    'precEntry','v4HuangPrecUnifiedDecodeV9','receiverUnchanged',true, ...
    'seedRoot',1032900000,'caseStartSec',[-366;0],'snrDb',(-30:-21).', ...
    'packetsPerCell',1000,'payloadSymbols',112,'physicalSymbols',120, ...
    'ricianKDb',10,'ricianCoherence','packet-flat', ...
    'nativeSameFramePairing',true,'paperSeparate157SymbolFrame',true, ...
    'sourcePaths',sourcePaths,'sourceSha256',sourceHashes, ...
    'inputPaths',inputPaths,'inputSha256',inputHashes);
end

function hash = localDigest(state)
copy = state;
if isfield(copy,'stateDigest'), copy = rmfield(copy,'stateDigest'); end
hash = localBytesHash(getByteStreamFromArray(orderfields(copy)));
end

function hash = localBytesHash(bytes)
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(typecast(uint8(bytes(:)),'int8'));
hash = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

function [raw,summary] = localTables(state,raw,summary,c)
raw.precRawErrors = state.precErrors;
raw.precCfoRmseBins = state.precCfoRmseBins;
raw.precStaticSelected = state.precStatic;
raw.precFailed = state.failed;
raw.precFailureMessage = state.failureMessage;
raw.precUsesForbiddenInput = state.usesForbiddenInput;
raw.precPhysicalSymbols = repmat(120,height(raw),1);
fields = {'precRawErrors','precSer','precLower95','precUpper95', ...
    'precMinusSameFrameIdealSer','precDifferenceLower95','precDifferenceUpper95', ...
    'precStaticPackets','precFailedPackets','precForbiddenPackets','precFrameDurationSec'};
for k = 1:numel(fields), summary.(fields{k}) = zeros(height(summary),1); end
for k = 1:height(summary)
    m = raw.caseIndex==summary.caseIndex(k) & raw.snrDb==summary.snrDb(k);
    errors = state.precErrors(m);
    difference = errors-raw.idealRawErrors(m);
    bounds = localBounds(errors,c.payloadSymbolCount,1032902000+k);
    paired = localBounds(difference,c.payloadSymbolCount,1032903000+k);
    summary.precRawErrors(k) = sum(errors);
    summary.precSer(k) = sum(errors)/112000;
    summary.precLower95(k) = bounds(1);
    summary.precUpper95(k) = bounds(2);
    summary.precMinusSameFrameIdealSer(k) = mean(difference)/112;
    summary.precDifferenceLower95(k) = paired(1);
    summary.precDifferenceUpper95(k) = paired(2);
    summary.precStaticPackets(k) = sum(state.precStatic(m));
    summary.precFailedPackets(k) = sum(state.failed(m));
    summary.precForbiddenPackets(k) = sum(state.usesForbiddenInput(m));
    summary.precFrameDurationSec(k) = 120*c.symbolDurationSec;
end
end

function bounds = localBounds(values,symbols,seed)
stream = RandStream('mt19937ar','Seed',seed);
n = numel(values);
sample = zeros(5000,1);
for k = 1:numel(sample), sample(k) = mean(values(randi(stream,n,n,1)))/symbols; end
bounds = prctile(sample,[2.5 97.5]);
end

function localPlot(summary,root)
for comparison = [false,true]
    if comparison, prefix = 'RICIAN_ALL_METHODS'; else, prefix = 'RICIAN_PREC'; end
    fig = figure('Visible','off','Color','w','Position',[100 100 1260 580]);
    tiles = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
    for ci = 1:2, localAxes(nexttile,summary(summary.caseIndex==ci,:),ci,comparison); end
    title(tiles,'Packet-flat Rician K=10 dB, SF12/no-LDRO/CR3, 1000 packets/point');
    exportgraphics(fig,fullfile(root,[prefix,'_CASE1_CASE2_SER.png']),'Resolution',220);
    close(fig);
    for ci = 1:2
        fig = figure('Visible','off','Color','w','Position',[100 100 850 610]);
        localAxes(axes('Parent',fig),summary(summary.caseIndex==ci,:),ci,comparison);
        exportgraphics(fig,fullfile(root,sprintf('%s_CASE%d_SER.png',prefix,ci)), ...
            'Resolution',220);
        close(fig);
    end
end
end

function localAxes(ax,data,ci,comparison)
data = sortrows(data,'snrDb');
hold(ax,'on');
plot(ax,data.snrDb,data.exactNoDopplerRicianSer,'-k','LineWidth',1.6, ...
    'DisplayName','Rician theory (no Doppler)');
plot(ax,data.snrDb,data.precSer,'-v','Color',[0.6350 0.0780 0.1840], ...
    'LineWidth',1.5,'DisplayName','Existing Huang PREC V9 (120 symbols)');
plot(ax,data.snrDb,data.idealSer,'-^','Color',[0.8500 0.3250 0.0980], ...
    'LineWidth',1.4,'DisplayName','Same-frame Ideal (PREC / V8)');
if comparison
    plot(ax,data.snrDb,data.senloraSer,'-o','Color',[0 0.4470 0.7410], ...
        'LineWidth',1.4,'DisplayName','SenLoRa V8 (120 symbols)');
    plot(ax,data.snrDb,data.paperSer,'-s','Color',[0.4660 0.6740 0.1880], ...
        'LineWidth',1.4,'DisplayName','Paper adapted V6 (157 symbols)');
    plot(ax,data.snrDb,data.paperFrameIdealSer,'--d','Color',[0.4940 0.1840 0.5560], ...
        'LineWidth',1.2,'DisplayName','Ideal (Paper frame)');
end
set(ax,'YScale','log'); xlim(ax,[-30 -21]); ylim(ax,[1e-3 1]); xticks(ax,-30:-21);
grid(ax,'on'); grid(ax,'minor'); xlabel(ax,'SNR (dB)'); ylabel(ax,'Raw SER');
title(ax,sprintf('Case %d: t_0 = %.0f s',ci,data.orbitStartSec(1)));
legend(ax,'Location','southwest','FontSize',9);
end
