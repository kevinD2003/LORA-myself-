function output = runSenloraSymmetricV8CaseSnrCurve(options)
%RUNSENLORASYMMETRICV8CASESNRCURVE Case1/Case2 SER from -30 to -21 dB.

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
parameters = v4LoadMethodAlignedR3ParametersV1();
caseStartSec = [-366;0];
snrDb = (-30:-21).';
packetsPerCell = 1000;
seedRoot = 1032700000;
shape = [numel(caseStartSec),numel(snrDb),packetsPerCell];
maximumPacket = min(options.StopAfterPacket,packetsPerCell);

manifestPath = fullfile(here,'v8_frozen_receiver_manifest.json');
theoryPath = fullfile(fileparts(paths.projectRoot),'Lora(theory)', ...
    'ideal_stage55_ser','results','ideal_ser_theory.csv');
localValidateFrozenManifest(manifestPath,here,plan);
theory = readtable(theoryPath);
if any(~ismember(snrDb,theory.snrDb))
    error('EXP5V8:CurveTheory','Exact theory is missing an SNR point.');
end

root = fullfile(paths.resultsRoot,'senlora_symmetric_v8', ...
    'case_snr_curve_minus30_to_minus21');
if ~isfolder(root)
    mkdir(root);
end
checkpointPath = fullfile(root,'CASE_SNR_CHECKPOINT.mat');
signature = localSignature(plan,config,parameters,caseStartSec, ...
    snrDb,packetsPerCell,seedRoot,manifestPath,theoryPath);
if isfile(checkpointPath)
    state = load(checkpointPath);
    localValidateCheckpoint(state,signature,shape);
else
    state = struct('signature',signature, ...
        'senloraErrors',nan(shape), ...
        'idealErrors',nan(shape), ...
        'firstErrors',nan(shape), ...
        'acceptedBlocks',nan(shape), ...
        'rateGain',nan(shape), ...
        'failed',false([shape,2]), ...
        'failureMessage',strings([shape,2]), ...
        'usesForbiddenInput',false(shape), ...
        'payloadSeed',zeros(shape), ...
        'noiseSeed',zeros(shape), ...
        'completed',false(shape));
    state.stateDigest = localDigest(state);
end

if any(~state.completed(:,:,1:maximumPacket),'all')
    pool = gcp('nocreate');
    if isempty(pool)
        parpool('local',options.WorkerCount);
    elseif pool.NumWorkers~=options.WorkerCount
        error('EXP5V8:WorkerCount', ...
            'The existing pool has the wrong worker count.');
    end
end

for blockStart = 1:5:maximumPacket
    packetIds = blockStart:min(maximumPacket,blockStart+4);
    pending = ~state.completed(:,:,packetIds);
    [caseRows,snrRows,packetColumns] = ind2sub( ...
        size(pending),find(pending));
    if isempty(caseRows)
        continue
    end
    jobPackets = packetIds(packetColumns).';
    jobCount = numel(caseRows);
    jobSenlora = nan(jobCount,1);
    jobIdeal = nan(jobCount,1);
    jobFirst = nan(jobCount,1);
    jobAccepted = nan(jobCount,1);
    jobGain = nan(jobCount,1);
    jobFailed = false(jobCount,2);
    jobMessage = strings(jobCount,2);
    jobForbidden = false(jobCount,1);
    jobPayloadSeed = zeros(jobCount,1);
    jobNoiseSeed = zeros(jobCount,1);
    parfor job = 1:jobCount
        packet = localEvaluate(caseRows(job),snrRows(job), ...
            jobPackets(job),caseStartSec,snrDb,seedRoot, ...
            config,plan,parameters);
        jobSenlora(job) = packet.senloraErrors;
        jobIdeal(job) = packet.idealErrors;
        jobFirst(job) = packet.firstErrors;
        jobAccepted(job) = packet.acceptedBlocks;
        jobGain(job) = packet.rateGain;
        jobFailed(job,:) = packet.failed;
        jobMessage(job,:) = packet.failureMessage;
        jobForbidden(job) = packet.usesForbiddenInput;
        jobPayloadSeed(job) = packet.payloadSeed;
        jobNoiseSeed(job) = packet.noiseSeed;
    end
    for job = 1:jobCount
        i = caseRows(job);
        j = snrRows(job);
        k = jobPackets(job);
        state.senloraErrors(i,j,k) = jobSenlora(job);
        state.idealErrors(i,j,k) = jobIdeal(job);
        state.firstErrors(i,j,k) = jobFirst(job);
        state.acceptedBlocks(i,j,k) = jobAccepted(job);
        state.rateGain(i,j,k) = jobGain(job);
        state.failed(i,j,k,:) = reshape(jobFailed(job,:),[1,1,1,2]);
        state.failureMessage(i,j,k,:) = ...
            reshape(jobMessage(job,:),[1,1,1,2]);
        state.usesForbiddenInput(i,j,k) = jobForbidden(job);
        state.payloadSeed(i,j,k) = jobPayloadSeed(job);
        state.noiseSeed(i,j,k) = jobNoiseSeed(job);
        state.completed(i,j,k) = true;
    end
    state.stateDigest = localDigest(state);
    localSaveCheckpoint(checkpointPath,state);
    fprintf(['Case SER curve: %d/%d frames, V8/Ideal errors=%d/%d, ' ...
        'failures=%d\n'],sum(state.completed,'all'),numel(state.completed), ...
        sum(state.senloraErrors,'all','omitnan'), ...
        sum(state.idealErrors,'all','omitnan'),sum(state.failed,'all'));
end

if ~all(state.completed,'all')
    output = struct('status','CASE_SNR_CURVE_IN_PROGRESS', ...
        'completedFrames',sum(state.completed,'all'), ...
        'totalFrames',numel(state.completed), ...
        'checkpointPath',checkpointPath);
    return
end

[raw,summary] = localTables(state,caseStartSec,snrDb,theory,c,seedRoot);
writetable(raw,fullfile(root,'CASE_SNR_RAW_PACKETS.csv'));
writetable(summary,fullfile(root,'CASE_SNR_SUMMARY.csv'));
save(fullfile(root,'CASE_SNR_RESULT.mat'),'-struct','state','-v7.3');
localPlot(summary,root);
output = struct('status','CASE_SNR_CURVE_COMPLETE', ...
    'summary',summary,'root',root,'failedFrames',sum(state.failed,'all'), ...
    'allForbiddenFlagsFalse',~any(state.usesForbiddenInput,'all'));
end

function packet = localEvaluate( ...
        caseIndex,snrIndex,packetId,caseStartSec,snrDb,seedRoot, ...
        config,plan,parameters)
c = config.parent;
key = struct('planVersion',plan.identity,'phase','case-ser-sweep', ...
    'track','two-case-native','channel','AWGN', ...
    'comparisonMode','frozen-v8-vs-ideal', ...
    'snrDb',snrDb(snrIndex),'replicateId',packetId, ...
    'packetId',packetId,'eventType','single-native-frame', ...
    'eventIndex',caseIndex,'sampleIndex',0);
ledger = v4EventRandomLedger(seedRoot,key);
packet = struct('senloraErrors',NaN,'idealErrors',NaN, ...
    'firstErrors',NaN,'acceptedBlocks',NaN,'rateGain',NaN, ...
    'failed',false(1,2),'failureMessage',strings(1,2), ...
    'usesForbiddenInput',false,'payloadSeed',ledger.payloadSeed, ...
    'noiseSeed',ledger.noiseSeed);
try
    frame = senloraSymmetricV8GenerateFrame( ...
        config,caseStartSec(caseIndex),snrDb(snrIndex),ledger);
    pilots = frame.observation.rxPhysical( ...
        frame.observation.layout.bootstrapRows,:);
    common = v4CommonBootstrap(pilots,c, ...
        SearchStepBins=parameters.searchStepBins);
catch exception
    packet.failed(:) = true;
    packet.failureMessage(:) = string(exception.message);
    return
end
try
    senlora = senloraSymmetricV8Decode( ...
        frame.observation,common,config,plan);
    truth = frame.truth.payloadPhysicalBins(:);
    packet.senloraErrors = sum(senlora.detectedPhysicalBins(:)~=truth);
    packet.firstErrors = sum( ...
        senlora.firstPassDetectedPhysicalBins(:)~=truth);
    packet.acceptedBlocks = sum(senlora.blockAccepted);
    packet.rateGain = senlora.rateGain;
    packet.usesForbiddenInput = ...
        localFlag(senlora,'usesPayloadTruth') || ...
        localFlag(senlora,'usesOrbitTruth') || ...
        localFlag(senlora,'usesCaseIdentity') || ...
        localFlag(senlora,'usesSnrInput') || ...
        localFlag(senlora,'usesTargetSer') || ...
        localFlag(senlora,'usesExplicitMidambles');
catch exception
    packet.senloraErrors = NaN;
    packet.firstErrors = NaN;
    packet.acceptedBlocks = NaN;
    packet.rateGain = NaN;
    packet.failed(1) = true;
    packet.failureMessage(1) = string(exception.message);
end
try
    ideal = exp1IdealDecode(frame,config);
    packet.idealErrors = sum( ...
        ideal.detectedPhysicalBins(:)~=frame.truth.payloadPhysicalBins(:));
catch exception
    packet.idealErrors = NaN;
    packet.failed(2) = true;
    packet.failureMessage(2) = string(exception.message);
end
end

function flag = localFlag(result,name)
flag = isfield(result,name) && logical(result.(name));
end

function signature = localSignature( ...
        plan,config,parameters,caseStartSec,snrDb,packetCount, ...
        seedRoot,manifestPath,theoryPath)
names = {'runSenloraSymmetricV8CaseSnrCurve', ...
    'senloraSymmetricV8Config','senloraSymmetricV8GenerateFrame', ...
    'senloraSymmetricV8Decode','senloraSymmetricV8JointBlockDecode', ...
    'senloraSymmetricV8BlockLikelihood', ...
    'senloraSymmetricV8BlendBootstrap','exp1IdealDecode', ...
    'v4CommonBootstrap','v4EventRandomLedger','v4DecodePayload'};
explicitPaths = strings(numel(names),1);
for index = 1:numel(names)
    path = which(names{index});
    if isempty(path)
        error('EXP5V8:CurveDependency','Cannot resolve %s.',names{index});
    end
    explicitPaths(index) = string(path);
end
required = string(matlab.codetools.requiredFilesAndProducts( ...
    which('runSenloraSymmetricV8CaseSnrCurve')));
allPaths = unique([required(:);explicitPaths]);
inScope = startsWith(allPaths,string(config.projectRoot)+filesep, ...
    'IgnoreCase',true) | startsWith(allPaths, ...
    string(config.parentRoot)+filesep,'IgnoreCase',true);
sourcePaths = sort(allPaths(inScope));
if isempty(sourcePaths)
    error('EXP5V8:CurveDependency','Source closure is empty.');
end
sourceHashes = strings(size(sourcePaths));
for index = 1:numel(sourcePaths)
    sourceHashes(index) = exp1Sha256(sourcePaths(index));
end
parameterPaths = unique([string(fullfile(fileparts(which( ...
    'v4LoadMethodAlignedParametersV1')), ...
    'method_aligned_selected_parameters_v1.json')); ...
    string(parameters.sourcePath)],'stable');
parameterHashes = strings(size(parameterPaths));
for index = 1:numel(parameterPaths)
    parameterHashes(index) = exp1Sha256(parameterPaths(index));
end
signature = struct('identity','V8-CASE-SNR-CURVE-M30-M21-V1', ...
    'receiverIdentity',plan.identity,'receiverVersion',plan.receiverVersion, ...
    'phase','case-ser-sweep','seedRoot',seedRoot, ...
    'caseStartSec',caseStartSec,'snrDb',snrDb, ...
    'packetsPerCell',packetCount, ...
    'd0Bins',plan.driftBlendStartBins, ...
    'd1Bins',plan.driftBlendEndBins, ...
    'commonSearchStepBins',parameters.searchStepBins, ...
    'executionSourcePaths',sourcePaths, ...
    'executionSourceSha256',sourceHashes, ...
    'parameterSourcePaths',parameterPaths, ...
    'parameterSourceSha256',parameterHashes, ...
    'frozenManifestPath',string(manifestPath), ...
    'frozenManifestSha256',exp1Sha256(manifestPath), ...
    'theoryPath',string(theoryPath), ...
    'theorySha256',exp1Sha256(theoryPath));
end

function localValidateFrozenManifest(path,sourceRoot,plan)
manifest = jsondecode(fileread(path));
if ~strcmp(manifest.officialEntry,'senloraSymmetricV8Decode') || ...
        ~strcmp(manifest.identity,plan.identity) || ...
        manifest.parameters.d0Bins~=plan.driftBlendStartBins || ...
        manifest.parameters.d1Bins~=plan.driftBlendEndBins || ...
        manifest.formalStarted
    error('EXP5V8:CurveManifest','Frozen receiver identity mismatch.');
end
names = {'senloraSymmetricV8Config.m', ...
    'senloraSymmetricV8Decode.m', ...
    'senloraSymmetricV8JointBlockDecode.m', ...
    'senloraSymmetricV8BlockLikelihood.m', ...
    'senloraSymmetricV8BlendBootstrap.m', ...
    'senloraSymmetricV8GenerateFrame.m'};
for index = 1:numel(names)
    field = matlab.lang.makeValidName(names{index});
    if ~strcmpi(manifest.sourceSha256.(field), ...
            exp1Sha256(fullfile(sourceRoot,names{index})))
        error('EXP5V8:CurveManifest', ...
            'Frozen source mismatch: %s.',names{index});
    end
end
end

function localValidateCheckpoint(state,signature,shape)
required = {'signature','senloraErrors','idealErrors','firstErrors', ...
    'acceptedBlocks','rateGain','failed','failureMessage', ...
    'usesForbiddenInput','payloadSeed','noiseSeed','completed','stateDigest'};
for index = 1:numel(required)
    if ~isfield(state,required{index})
        error('EXP5V8:CurveCheckpoint','Missing %s.',required{index});
    end
end
if ~strcmp(jsonencode(state.signature),jsonencode(signature)) || ...
        ~isequal(size(state.senloraErrors),shape) || ...
        ~isequal(size(state.failed),[shape,2]) || ...
        ~isequal(size(state.completed),shape) || ...
        ~strcmp(state.stateDigest,localDigest(state))
    error('EXP5V8:CurveCheckpoint','Checkpoint is incompatible.');
end
end

function localSaveCheckpoint(path,state)
temporary = path+".tmp.mat";
save(temporary,'-struct','state','-v7.3');
probe = load(temporary);
if ~strcmp(probe.stateDigest,localDigest(probe))
    error('EXP5V8:CurveCheckpointWrite','Digest verification failed.');
end
[moved,message] = movefile(temporary,path,'f');
if ~moved
    error('EXP5V8:CurveCheckpointWrite','%s',message);
end
end

function hash = localDigest(state)
digest = java.security.MessageDigest.getInstance('SHA-256');
bytes = getByteStreamFromArray({state.signature,state.senloraErrors, ...
    state.idealErrors,state.firstErrors,state.acceptedBlocks, ...
    state.rateGain,state.failed,state.failureMessage, ...
    state.usesForbiddenInput,state.payloadSeed,state.noiseSeed, ...
    state.completed});
digest.update(typecast(uint8(bytes(:)),'int8'));
hash = lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

function [raw,summary] = localTables(state,caseStartSec,snrDb,theory,c,seedRoot)
caseCount = numel(caseStartSec);
snrCount = numel(snrDb);
packetCount = size(state.completed,3);
rawRows = cell(numel(state.completed),16);
row = 0;
for ci = 1:caseCount
    for si = 1:snrCount
        for packetId = 1:packetCount
            row = row+1;
            rawRows(row,:) = {ci,caseStartSec(ci),snrDb(si),packetId, ...
                state.payloadSeed(ci,si,packetId), ...
                state.noiseSeed(ci,si,packetId), ...
                state.senloraErrors(ci,si,packetId), ...
                state.idealErrors(ci,si,packetId), ...
                state.firstErrors(ci,si,packetId), ...
                state.acceptedBlocks(ci,si,packetId), ...
                state.rateGain(ci,si,packetId), ...
                state.failed(ci,si,packetId,1), ...
                state.failed(ci,si,packetId,2), ...
                state.usesForbiddenInput(ci,si,packetId), ...
                seedRoot,c.payloadSymbolCount};
        end
    end
end
raw = cell2table(rawRows,'VariableNames',{ ...
    'caseIndex','orbitStartSec','snrDb','packetId', ...
    'payloadSeed','noiseSeed','senloraRawErrors','idealRawErrors', ...
    'firstRawErrors','acceptedBlocks','rateGain','senloraFailed', ...
    'idealFailed','usesForbiddenInput','rootSeed','payloadSymbols'});

summaryRows = cell(caseCount*snrCount,15);
row = 0;
for ci = 1:caseCount
    for si = 1:snrCount
        row = row+1;
        v8 = reshape(state.senloraErrors(ci,si,:),[],1);
        ideal = reshape(state.idealErrors(ci,si,:),[],1);
        v8Failed = reshape(state.failed(ci,si,:,1),[],1);
        idealFailed = reshape(state.failed(ci,si,:,2),[],1);
        v8(v8Failed) = NaN;
        ideal(idealFailed) = NaN;
        validV8 = sum(isfinite(v8));
        validIdeal = sum(isfinite(ideal));
        v8Errors = sum(v8,'omitnan');
        idealErrors = sum(ideal,'omitnan');
        theorySer = theory.ser(theory.snrDb==snrDb(si));
        v8Ser = localSer(v8Errors,validV8,c.payloadSymbolCount);
        idealSer = localSer(idealErrors,validIdeal,c.payloadSymbolCount);
        v8Bounds = localClusterBounds( ...
            v8,c.payloadSymbolCount,seedRoot+1000*ci+10*si+1);
        idealBounds = localClusterBounds( ...
            ideal,c.payloadSymbolCount,seedRoot+1000*ci+10*si+2);
        summaryRows(row,:) = {ci,caseStartSec(ci),snrDb(si),packetCount, ...
            validV8,validIdeal,v8Errors,idealErrors,v8Ser,idealSer, ...
            theorySer,v8Bounds(1),v8Bounds(2), ...
            idealBounds(1),idealBounds(2)};
    end
end
summary = cell2table(summaryRows,'VariableNames',{ ...
    'caseIndex','orbitStartSec','snrDb','packets', ...
    'validSenloraPackets','validIdealPackets', ...
    'senloraRawErrors','idealRawErrors','senloraSer','idealSer', ...
    'exactTheorySer','senloraLower95','senloraUpper95', ...
    'idealLower95','idealUpper95'});
end

function ser = localSer(errors,validPackets,symbolsPerPacket)
if validPackets==0
    ser = NaN;
else
    ser = errors/(validPackets*symbolsPerPacket);
end
end

function bounds = localClusterBounds(errors,symbolsPerPacket,seed)
errors = errors(isfinite(errors));
n = numel(errors);
if n==0
    bounds = [NaN NaN];
    return
end
draws = 5000;
samples = zeros(draws,1);
stream = RandStream('mt19937ar','Seed',seed);
for draw = 1:draws
    sampled = randi(stream,n,n,1);
    samples(draw) = sum(errors(sampled))/(n*symbolsPerPacket);
end
bounds = prctile(samples,[2.5 97.5]);
end

function localPlot(summary,root)
combined = figure('Visible','off','Color','w', ...
    'Position',[100 100 1120 540]);
tiles = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
for ci = 1:2
    ax = nexttile;
    localCaseAxes(ax,summary(summary.caseIndex==ci,:),ci);
end
title(tiles,'Frozen V8 SER vs SNR: 1000 native packets per point');
exportgraphics(combined,fullfile(root,'CASE1_CASE2_SER_SNR.png'), ...
    'Resolution',220);
close(combined);
for ci = 1:2
    fig = figure('Visible','off','Color','w', ...
        'Position',[100 100 760 560]);
    ax = axes('Parent',fig);
    localCaseAxes(ax,summary(summary.caseIndex==ci,:),ci);
    exportgraphics(fig,fullfile(root,sprintf('CASE%d_SER_SNR.png',ci)), ...
        'Resolution',220);
    close(fig);
end
end

function localCaseAxes(ax,data,caseIndex)
data = sortrows(data,'snrDb');
hold(ax,'on');
plot(ax,data.snrDb,data.exactTheorySer,'-k','LineWidth',1.6, ...
    'DisplayName','Exact AWGN theory');
plot(ax,data.snrDb,data.senloraSer,'-o', ...
    'Color',[0 0.4470 0.7410],'LineWidth',1.4, ...
    'MarkerSize',6,'DisplayName','SenLoRa V8');
plot(ax,data.snrDb,data.idealSer,'-^', ...
    'Color',[0.8500 0.3250 0.0980],'LineWidth',1.4, ...
    'MarkerSize',6,'DisplayName','Empirical Ideal');
set(ax,'YScale','log');
xlim(ax,[-30 -21]);
ylim(ax,[1e-5 1]);
xticks(ax,-30:-21);
grid(ax,'on');
grid(ax,'minor');
xlabel(ax,'SNR (dB)');
ylabel(ax,'Raw SER');
title(ax,sprintf('Case %d: t_0 = %.0f s',caseIndex,data.orbitStartSec(1)));
legend(ax,'Location','southwest');
end
